#!/usr/bin/env python3
"""Telegram bridge for the couple admin bot.

Private chats with the bot arrive as message updates and are answered with
sendMessage. Mentions in a chat the bot is not a member of arrive as
guest_message updates and are answered with answerGuestQuery. Confirm / Cancel
come back as callback_query, and the callback is what writes through gws.
"""

import json
import logging
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

LOG = logging.getLogger("telegram-bot")

EXPENSE_RE = re.compile(
    r"^(?:/expense\s+)?(?P<card>[A-Za-z][\w-]*)\s+\$?(?P<amount>\d+(?:\.\d{1,2})?)\b\s*(?P<note>.*)$",
    re.IGNORECASE,
)
TASK_RE = re.compile(r"^/task\s+(?P<title>.+)$", re.IGNORECASE)
CAL_RE = re.compile(
    r"^/cal(?:endar)?\s+(?P<date>\d{4}-\d{2}-\d{2})\s+(?P<time>\d{2}:\d{2})"
    r"(?:\s+(?P<minutes>\d{1,4}))?\s+(?P<summary>.+)$",
    re.IGNORECASE,
)
MENTION_RE = re.compile(r"(?<!\S)@\w+")


def strip_mentions(text):
    return MENTION_RE.sub("", text).strip()


def command_text(message):
    text = strip_mentions(message.get("text") or message.get("caption") or "")
    if text:
        return text
    reply = message.get("reply_to_message") or {}
    return (reply.get("text") or reply.get("caption") or "").strip()


def parse_command(text, timezone):
    text = text.strip()
    if not text or text.lower() in {"/help", "help"}:
        return {"kind": "help"}

    task = TASK_RE.match(text)
    if task:
        return {"kind": "task", "title": task.group("title").strip()}

    cal = CAL_RE.match(text)
    if cal:
        start, end = calendar_range(
            cal.group("date"),
            cal.group("time"),
            cal.group("minutes"),
            timezone,
        )
        return {
            "kind": "calendar",
            "summary": cal.group("summary").strip(),
            "start": start,
            "end": end,
        }

    expense = EXPENSE_RE.match(text)
    if expense and not text.lower().startswith("/cal"):
        return {
            "kind": "expense",
            "card": expense.group("card"),
            "amount": expense.group("amount"),
            "note": expense.group("note").strip(),
        }

    return None


def calendar_range(date_s, time_s, minutes, timezone):
    tz = ZoneInfo(timezone)
    start = datetime.strptime(f"{date_s} {time_s}", "%Y-%m-%d %H:%M").replace(tzinfo=tz)
    duration = int(minutes) if minutes else 60
    end = start + timedelta(minutes=duration)
    return start.isoformat(), end.isoformat()


def help_text():
    return (
        "Send one of:\n"
        "amex 15\n"
        "/expense amex 15 coffee\n"
        "/task buy milk\n"
        "/cal 2026-10-25 15:00 dentist\n"
        "/cal 2026-10-25 15:00 90 dentist"
    )


def expense_summary(action, payer, today):
    lines = [
        "Log expense?",
        f"Date: {today}",
        f"Card: {action['card']}",
        f"Amount: {action['amount']}",
        f"Payer: {payer}",
    ]
    if action.get("note"):
        lines.append(f"Note: {action['note']}")
    return "\n".join(lines)


def action_summary(action, settings, today):
    kind = action["kind"]
    if kind == "help":
        return help_text()
    if kind == "expense":
        return expense_summary(action, settings["payer"], today)
    if kind == "task":
        return f"Add task?\n{action['title']}"
    if kind == "calendar":
        return (
            "Add event?\n"
            f"{action['summary']}\n"
            f"{action['start']}\n"
            f"{action['end']}"
        )
    return help_text()


def buttons(action_id):
    return [[
        {"text": "Confirm", "callback_data": f"c:{action_id}"},
        {"text": "Cancel", "callback_data": f"x:{action_id}"},
    ]]


class Bot:
    def __init__(self, settings, token, state_dir, gws, cursor_agent):
        self.settings = settings
        self.token = token
        self.state_dir = Path(state_dir)
        self.gws = gws
        self.cursor_agent = cursor_agent
        self.state_dir.mkdir(parents=True, exist_ok=True)

    def today(self):
        return datetime.now(ZoneInfo(self.settings["timezone"])).date().isoformat()

    def api(self, method, payload):
        url = f"https://api.telegram.org/bot{self.token}/{method}"
        data = json.dumps(payload).encode()
        request = urllib.request.Request(
            url,
            data=data,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=70) as response:
                body = json.load(response)
        except urllib.error.HTTPError as err:
            detail = err.read().decode("utf-8", "replace")
            raise RuntimeError(f"{method} HTTP {err.code}: {detail}") from err
        if not body.get("ok"):
            raise RuntimeError(f"{method} failed: {body}")
        return body["result"]

    def answer_guest(self, query_id, text, markup=None):
        result = {
            "type": "article",
            "id": "1",
            "title": "Secretary",
            "input_message_content": {"message_text": text},
        }
        if markup:
            result["reply_markup"] = {"inline_keyboard": markup}
        sent = self.api("answerGuestQuery", {
            "guest_query_id": query_id,
            "result": result,
        })
        return sent["inline_message_id"]

    def edit(self, inline_message_id, text, markup=None):
        payload = {"inline_message_id": inline_message_id, "text": text}
        if markup is not None:
            payload["reply_markup"] = {"inline_keyboard": markup}
        self.api("editMessageText", payload)

    def send_message(self, chat_id, text, markup=None):
        payload = {"chat_id": chat_id, "text": text}
        if markup:
            payload["reply_markup"] = {"inline_keyboard": markup}
        return self.api("sendMessage", payload)

    def edit_confirmation(self, record, text, markup=None, callback=None):
        inline_id = record.get("inline_message_id")
        if inline_id:
            self.edit(inline_id, text, markup)
            return
        source = (callback or {}).get("message") or {}
        chat_id = (source.get("chat") or {}).get("id", record.get("reply_chat_id"))
        message_id = source.get("message_id", record.get("reply_message_id"))
        if chat_id is None or message_id is None:
            return
        payload = {"chat_id": chat_id, "message_id": message_id, "text": text}
        if markup is not None:
            payload["reply_markup"] = {"inline_keyboard": markup}
        self.api("editMessageText", payload)

    def allowed(self, message):
        chat_id = (message.get("chat") or {}).get("id")
        user_id = (message.get("from") or {}).get("id")
        chats = self.settings.get("allowedChatIds") or []
        users = self.settings.get("allowedUserIds") or []
        if chats and chat_id not in chats:
            return False
        if users and user_id not in users:
            return False
        return True

    def load_pending(self):
        path = self.state_dir / "pending.json"
        if not path.exists():
            return {}
        return json.loads(path.read_text())

    def save_pending(self, pending):
        path = self.state_dir / "pending.json"
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(pending))
        tmp.replace(path)

    def remember(self, action, message, inline_message_id):
        pending = self.load_pending()
        action_id = os.urandom(4).hex()
        pending[action_id] = {
            "action": action,
            "chat_id": (message.get("chat") or {}).get("id"),
            "user_id": (message.get("from") or {}).get("id"),
            "inline_message_id": inline_message_id,
            "status": "pending",
        }
        self.save_pending(pending)
        return action_id

    def propose(self, query_id, message, action):
        if action["kind"] == "help":
            self.answer_guest(query_id, help_text())
            return
        text = action_summary(action, self.settings, self.today())
        action_id = self.remember(action, message, None)
        inline_id = self.answer_guest(query_id, text, buttons(action_id))
        pending = self.load_pending()
        pending[action_id]["inline_message_id"] = inline_id
        self.save_pending(pending)

    def handle_guest(self, message):
        query_id = message.get("guest_query_id")
        if not query_id:
            LOG.info("guest message without guest_query_id")
            return
        chat_id = (message.get("chat") or {}).get("id")
        user_id = (message.get("from") or {}).get("id")
        LOG.info("guest chat_id=%s user_id=%s", chat_id, user_id)
        if not self.allowed(message):
            self.answer_guest(query_id, "This chat is not allowed to use the secretary.")
            return
        text = command_text(message)
        action = parse_command(text, self.settings["timezone"])
        if action is None and self.settings.get("agent") and self.cursor_agent:
            self.propose_with_agent(query_id, message, text)
            return
        if action is None:
            self.answer_guest(query_id, help_text())
            return
        self.propose(query_id, message, action)

    def handle_private(self, message):
        chat = message.get("chat") or {}
        if chat.get("type") != "private":
            return
        if (message.get("from") or {}).get("is_bot"):
            return
        chat_id = chat.get("id")
        user_id = (message.get("from") or {}).get("id")
        LOG.info("private chat_id=%s user_id=%s", chat_id, user_id)
        if not self.allowed(message):
            self.send_message(chat_id, "This chat is not allowed to use the secretary.")
            return
        text = command_text(message)
        if text == "/start" or text.startswith("/start "):
            text = text.split(maxsplit=1)[1] if " " in text else ""
        if not text:
            self.send_message(chat_id, help_text())
            return
        action = parse_command(text, self.settings["timezone"])
        if action is None and self.settings.get("agent") and self.cursor_agent:
            self.propose_private_with_agent(message, text)
            return
        if action is None or action["kind"] == "help":
            self.send_message(chat_id, help_text())
            return
        self.propose_private(message, action)

    def propose_private(self, message, action):
        chat_id = message["chat"]["id"]
        text = action_summary(action, self.settings, self.today())
        action_id = self.remember(action, message, None)
        sent = self.send_message(chat_id, text, buttons(action_id))
        pending = self.load_pending()
        pending[action_id]["reply_chat_id"] = chat_id
        pending[action_id]["reply_message_id"] = sent["message_id"]
        self.save_pending(pending)

    def propose_private_with_agent(self, message, text):
        chat_id = message["chat"]["id"]
        sent = self.send_message(chat_id, "Working on it…")
        placeholder = {
            "reply_chat_id": chat_id,
            "reply_message_id": sent["message_id"],
        }
        try:
            action = self.interpret(text)
        except (OSError, subprocess.TimeoutExpired, RuntimeError, json.JSONDecodeError) as err:
            LOG.exception("cursor-agent failed")
            self.edit_confirmation(placeholder, f"Could not read that.\n{err}")
            return
        if action is None or action.get("kind") in {None, "help", "none"}:
            reply = (action or {}).get("reply") or help_text()
            self.edit_confirmation(placeholder, reply)
            return
        summary = action_summary(action, self.settings, self.today())
        action_id = self.remember(action, message, None)
        pending = self.load_pending()
        pending[action_id]["reply_chat_id"] = chat_id
        pending[action_id]["reply_message_id"] = sent["message_id"]
        self.save_pending(pending)
        self.edit_confirmation(pending[action_id], summary, buttons(action_id))

    def propose_with_agent(self, query_id, message, text):
        inline_id = self.answer_guest(query_id, "Working on it…")
        try:
            action = self.interpret(text)
        except (OSError, subprocess.TimeoutExpired, RuntimeError, json.JSONDecodeError) as err:
            LOG.exception("cursor-agent failed")
            self.edit(inline_id, f"Could not read that.\n{err}")
            return
        if action is None or action.get("kind") in {None, "help", "none"}:
            reply = (action or {}).get("reply") or help_text()
            self.edit(inline_id, reply)
            return
        summary = action_summary(action, self.settings, self.today())
        action_id = self.remember(action, message, inline_id)
        self.edit(inline_id, summary, buttons(action_id))

    def interpret(self, text):
        prompt = (
            "Turn this couple-chat admin message into one JSON object and nothing else. "
            "Do not call tools. action is expense, task, calendar, or none. "
            "expense needs card, amount (number as a string), note. "
            "task needs title. "
            f"calendar needs summary, start, and end as RFC3339 in {self.settings['timezone']}. "
            "none needs reply, a short question asking for the missing detail. "
            f"Message: {text}"
        )
        proc = subprocess.run(
            [
                self.cursor_agent,
                "-p",
                "--mode",
                "ask",
                "--trust",
                "--workspace",
                self.settings["workspace"],
                "--output-format",
                "text",
                prompt,
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=180,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip() or f"cursor-agent exited {proc.returncode}")
        match = re.search(r"\{.*\}", proc.stdout, re.DOTALL)
        if not match:
            raise RuntimeError("cursor-agent returned no JSON")
        raw = json.loads(match.group(0))
        kind = raw.get("action")
        if kind == "expense":
            return {
                "kind": "expense",
                "card": str(raw["card"]),
                "amount": str(raw["amount"]),
                "note": str(raw.get("note") or ""),
            }
        if kind == "task":
            return {"kind": "task", "title": str(raw["title"])}
        if kind == "calendar":
            return {
                "kind": "calendar",
                "summary": str(raw["summary"]),
                "start": str(raw["start"]),
                "end": str(raw["end"]),
            }
        return {"kind": "none", "reply": str(raw.get("reply") or help_text())}

    def handle_callback(self, callback):
        data = callback.get("data") or ""
        callback_id = callback["id"]
        if len(data) < 3 or data[1] != ":" or data[0] not in {"c", "x"}:
            self.api("answerCallbackQuery", {"callback_query_id": callback_id})
            return
        action_id = data[2:]
        pending = self.load_pending()
        record = pending.get(action_id)
        if record is None:
            self.api("answerCallbackQuery", {
                "callback_query_id": callback_id,
                "text": "That confirmation expired.",
            })
            return
        user_id = (callback.get("from") or {}).get("id")
        if record.get("user_id") not in {None, user_id}:
            self.api("answerCallbackQuery", {
                "callback_query_id": callback_id,
                "text": "Only the person who asked can confirm.",
            })
            return
        if data[0] == "x":
            pending.pop(action_id, None)
            self.save_pending(pending)
            self.api("answerCallbackQuery", {"callback_query_id": callback_id, "text": "Cancelled."})
            self.edit_confirmation(record, "Cancelled.", [], callback)
            return
        if record.get("status") == "running":
            self.api("answerCallbackQuery", {"callback_query_id": callback_id, "text": "Already saving."})
            return
        record["status"] = "running"
        self.save_pending(pending)
        self.api("answerCallbackQuery", {"callback_query_id": callback_id, "text": "Saving…"})
        try:
            result = self.perform(record["action"])
        except (OSError, subprocess.TimeoutExpired, RuntimeError) as err:
            LOG.exception("gws failed")
            record["status"] = "pending"
            pending[action_id] = record
            self.save_pending(pending)
            self.edit_confirmation(record, f"Failed.\n{err}", buttons(action_id), callback)
            return
        pending.pop(action_id, None)
        self.save_pending(pending)
        self.edit_confirmation(record, result, [], callback)

    def perform(self, action):
        kind = action["kind"]
        if kind == "expense":
            return self.append_expense(action)
        if kind == "task":
            return self.insert_task(action)
        if kind == "calendar":
            return self.insert_event(action)
        raise RuntimeError(f"unknown action {kind}")

    def run_gws(self, args):
        proc = subprocess.run(
            [self.gws, *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=60,
        )
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip()
            raise RuntimeError(detail or f"gws exited {proc.returncode}")
        return proc.stdout.strip()

    def append_expense(self, action):
        spreadsheet = self.settings.get("spreadsheetId") or ""
        if not spreadsheet:
            raise RuntimeError("spreadsheet-id is not set")
        row = [
            self.today(),
            action["card"],
            action["amount"],
            self.settings["payer"],
            action.get("note") or "",
        ]
        self.run_gws([
            "sheets",
            "+append",
            "--spreadsheet",
            spreadsheet,
            "--range",
            self.settings["sheetRange"],
            "--json-values",
            json.dumps([row]),
        ])
        return f"Logged {action['card']} {action['amount']} as {self.settings['payer']}."

    def insert_event(self, action):
        self.run_gws([
            "calendar",
            "+insert",
            "--calendar",
            self.settings["calendarId"],
            "--summary",
            action["summary"],
            "--start",
            action["start"],
            "--end",
            action["end"],
        ])
        return f"Added {action['summary']}."

    def insert_task(self, action):
        self.run_gws([
            "tasks",
            "tasks",
            "insert",
            "--params",
            json.dumps({"tasklist": self.settings["tasklist"]}),
            "--json",
            json.dumps({"title": action["title"]}),
        ])
        return f"Added task: {action['title']}"

    def offset(self):
        path = self.state_dir / "offset"
        if not path.exists():
            return None
        raw = path.read_text().strip()
        return int(raw) if raw else None

    def save_offset(self, offset):
        path = self.state_dir / "offset"
        tmp = path.with_suffix(".tmp")
        tmp.write_text(str(offset))
        tmp.replace(path)

    def poll_once(self):
        payload = {
            "timeout": 50,
            "allowed_updates": ["message", "guest_message", "callback_query"],
        }
        offset = self.offset()
        if offset is not None:
            payload["offset"] = offset
        url = f"https://api.telegram.org/bot{self.token}/getUpdates"
        data = json.dumps(payload).encode()
        request = urllib.request.Request(
            url,
            data=data,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=70) as response:
                body = json.load(response)
        except urllib.error.HTTPError as err:
            detail = err.read().decode("utf-8", "replace")
            raise RuntimeError(f"getUpdates HTTP {err.code}: {detail}") from err
        if not body.get("ok"):
            raise RuntimeError(f"getUpdates failed: {body}")
        for update in body["result"]:
            try:
                if "guest_message" in update:
                    self.handle_guest(update["guest_message"])
                elif "message" in update:
                    self.handle_private(update["message"])
                elif "callback_query" in update:
                    self.handle_callback(update["callback_query"])
            except Exception:
                LOG.exception("update %s failed", update.get("update_id"))
            self.save_offset(update["update_id"] + 1)

    def run(self):
        LOG.info("polling private chats and guest mentions")
        while True:
            try:
                self.poll_once()
            except Exception:
                LOG.exception("poll failed")
                time.sleep(5)


def load_settings():
    with open(os.environ["TELEGRAM_BOT_SETTINGS"], encoding="utf-8") as handle:
        return json.load(handle)


def self_test():
    assert parse_command("amex $15", "Australia/Sydney") == {
        "kind": "expense",
        "card": "amex",
        "amount": "15",
        "note": "",
    }
    assert parse_command("/expense Visa 20.50 lunch", "Australia/Sydney")["note"] == "lunch"
    assert parse_command("/task buy milk", "Australia/Sydney") == {
        "kind": "task",
        "title": "buy milk",
    }
    cal = parse_command("/cal 2026-10-25 15:00 dentist", "Australia/Sydney")
    assert cal["summary"] == "dentist"
    assert cal["start"].startswith("2026-10-25T15:00:00")
    assert cal["end"].startswith("2026-10-25T16:00:00")
    long = parse_command("/cal 2026-10-25 15:00 90 long visit", "Australia/Sydney")
    assert long["end"].startswith("2026-10-25T16:30:00")
    mentioned = strip_mentions("@secretary amex 15")
    assert parse_command(mentioned, "Australia/Sydney")["card"] == "amex"
    replied = command_text({
        "text": "@secretary",
        "reply_to_message": {"text": "amex $15"},
    })
    assert parse_command(replied, "Australia/Sydney")["amount"] == "15"
    assert parse_command("/task", "Australia/Sydney") is None
    assert parse_command("hello", "Australia/Sydney") is None
    print("ok")


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    token = Path(os.environ["TELEGRAM_BOT_TOKEN_FILE"]).read_text(encoding="utf-8").strip()
    if not token or token == "REPLACE_ME":
        raise SystemExit("telegram_bot_token is missing")
    bot = Bot(
        settings=load_settings(),
        token=token,
        state_dir=os.environ["STATE_DIRECTORY"],
        gws=os.environ["GWS"],
        cursor_agent=os.environ.get("CURSOR_AGENT") or "",
    )
    bot.run()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        self_test()
    else:
        main()
