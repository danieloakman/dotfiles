use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use frankenstein::types::Message;
use frankenstein::updates::{Update, UpdateContent};
use uuid::Uuid;

use crate::settings::Settings;
use crate::state::{PendingAsk, Shared};
use crate::telegram::Telegram;

pub struct App {
    settings: Settings,
    telegram: Telegram,
}

impl App {
    pub fn new(settings: Settings, telegram: Telegram) -> Self {
        Self { settings, telegram }
    }

    pub fn run_poll(&self, state: Arc<Shared>) -> Result<(), String> {
        log::info!("polling agent telegram updates");
        loop {
            if let Err(err) = self.poll_once(&state) {
                log::error!("poll failed: {err}");
                std::thread::sleep(Duration::from_secs(5));
            }
        }
    }

    fn poll_once(&self, state: &Shared) -> Result<(), String> {
        let updates = self.telegram.updates(state.offset())?;
        for update in updates {
            let next = i64::from(update.update_id) + 1;
            if let Err(err) = self.handle(update, state) {
                log::error!("update failed: {err}");
            }
            state.set_offset(next)?;
        }
        Ok(())
    }

    fn handle(&self, update: Update, state: &Shared) -> Result<(), String> {
        match update.content {
            UpdateContent::Message(message) => self.handle_message(*message, state),
            _ => Ok(()),
        }
    }

    fn handle_message(&self, message: Message, state: &Shared) -> Result<(), String> {
        let chat_id = message.chat.id;
        if !self.settings.chat_ids.contains(&chat_id) {
            return Ok(());
        }
        let user_id = message.from.as_ref().map(|u| u.id);
        if !self.settings.allows_user(user_id) {
            log::info!("ignored message from disallowed user_id={user_id:?}");
            return Ok(());
        }
        let Some(text) = message.text.as_deref().map(str::trim) else {
            return Ok(());
        };
        if text.is_empty() {
            return Ok(());
        }

        // Prefer reply-to an ask message.
        if let Some(reply) = message.reply_to_message.as_ref() {
            if let Some(ask_id) = state.ask_id_for_message(reply.message_id) {
                let answer = strip_answer_prefix(text).to_string();
                if state.complete_ask(&ask_id, Ok(answer.clone())) {
                    let _ = self.telegram.send(
                        chat_id,
                        &format!("✅ recorded answer for `{ask_id}`"),
                    );
                }
                return Ok(());
            }
        }

        // /a <answer> or /answer <answer> against the latest open ask.
        if let Some(rest) = text
            .strip_prefix("/a ")
            .or_else(|| text.strip_prefix("/answer "))
            .or_else(|| {
                if text == "/a" || text == "/answer" {
                    Some("")
                } else {
                    None
                }
            })
        {
            let answer = rest.trim();
            if answer.is_empty() {
                let _ = self
                    .telegram
                    .send(chat_id, "Usage: /a <answer> (or reply to the ask)");
                return Ok(());
            }
            let Some(ask_id) = state.latest_ask_id() else {
                let _ = self.telegram.send(chat_id, "No open ask to answer.");
                return Ok(());
            };
            if state.complete_ask(&ask_id, Ok(answer.to_string())) {
                let _ = self
                    .telegram
                    .send(chat_id, &format!("✅ recorded answer for `{ask_id}`"));
            }
            return Ok(());
        }

        if text == "/help" {
            let _ = self.telegram.send(
                chat_id,
                "Agent bridge.\n\
                 Automation sends notices and asks here.\n\
                 Reply to an ask, or send `/a <answer>`.",
            );
        }
        Ok(())
    }

    pub fn send(&self, role: Option<&str>, text: &str) -> Result<i32, String> {
        let body = format_message(role, text, None);
        let chat_id = self.primary_chat()?;
        self.telegram.send(chat_id, &body)
    }

    pub fn ask(
        &self,
        role: Option<&str>,
        text: &str,
        timeout: Duration,
        state: &Shared,
    ) -> Result<(String, String), String> {
        let ask_id = short_id();
        let body = format_message(role, text, Some(&ask_id));
        let chat_id = self.primary_chat()?;
        let message_id = self.telegram.send(chat_id, &body)?;
        let ask = PendingAsk {
            id: ask_id.clone(),
            role: role.unwrap_or("agent").to_string(),
            chat_id,
            message_id,
            created: now_rfc3339(),
        };
        let waiter = state.register_ask(ask);
        match Shared::wait_for_answer(&waiter, timeout) {
            Ok(answer) => Ok((ask_id, answer)),
            Err(err) => {
                state.complete_ask(&ask_id, Err(err.clone()));
                Err(err)
            }
        }
    }

    fn primary_chat(&self) -> Result<i64, String> {
        self.settings
            .chat_ids
            .first()
            .copied()
            .ok_or_else(|| "no chat ids configured".into())
    }
}

fn format_message(role: Option<&str>, text: &str, ask_id: Option<&str>) -> String {
    let role = role.unwrap_or("agent");
    match ask_id {
        Some(id) => format!(
            "[{role}] ask `{id}`\n\n{text}\n\nReply to this message, or `/a <answer>`."
        ),
        None => format!("[{role}]\n{text}"),
    }
}

fn strip_answer_prefix(text: &str) -> &str {
    text.strip_prefix("/a ")
        .or_else(|| text.strip_prefix("/answer "))
        .unwrap_or(text)
        .trim()
}

fn short_id() -> String {
    let uuid = Uuid::new_v4().to_string();
    uuid[..8].to_string()
}

fn now_rfc3339() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("{secs}")
}
