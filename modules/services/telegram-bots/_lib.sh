# Shared helpers for brown-fam telegram-bots command scripts.
# Sourced by expense / task / cal / default runners.

: "${TELEGRAM_BOTS_INSTANCE:=brown-fam}"
: "${TELEGRAM_BOTS_CONTEXT:=}"
: "${TELEGRAM_BOTS_TIMEZONE:=Australia/Sydney}"
: "${TELEGRAM_BOTS_CHAT_ID:=}"
: "${TELEGRAM_BOTS_USER_ID:=}"

bf_die() {
  echo "$*" >&2
  exit 1
}

bf_context() {
  if [ -z "${TELEGRAM_BOTS_CONTEXT}" ]; then
    echo "{}"
  else
    printf '%s' "${TELEGRAM_BOTS_CONTEXT}"
  fi
}

bf_ctx_get() {
  local key="$1"
  local default="${2:-}"
  bf_context | jq -r --arg k "$key" --arg d "$default" '
    if has($k) and .[$k] != null then .[$k] | tostring else $d end
  '
}

bf_today() {
  TZ="${TELEGRAM_BOTS_TIMEZONE}" date +%Y-%m-%d
}

bf_ask() {
  local prompt="$1"
  local args=(
    telegram-bots --instance "${TELEGRAM_BOTS_INSTANCE}" ask
    --choice confirm=Confirm --choice cancel=Cancel
  )
  if [ -n "${TELEGRAM_BOTS_CHAT_ID}" ]; then
    args+=(--chat-id "${TELEGRAM_BOTS_CHAT_ID}")
  fi
  args+=("$prompt")
  "${args[@]}"
}

# Returns 0 on confirm, 1 on cancel / empty.
bf_confirm() {
  local prompt="$1"
  local choice
  choice="$(bf_ask "$prompt")" || return 1
  [ "$choice" = "confirm" ]
}

bf_normalize_payer_label() {
  local label="$1"
  label="${label#"${label%%[![:space:]]*}"}"
  label="${label%"${label##*[![:space:]]}"}"
  label="${label#@}"
  printf '%s' "$label" | tr '[:upper:]' '[:lower:]'
}

# Resolve a name/alias to canonical payer name via context.payers JSON.
bf_resolve_payer() {
  local label name
  label="$(bf_normalize_payer_label "$1")"
  [ -n "$label" ] || return 1
  name="$(bf_context | jq -r --arg label "$label" '
    (.payers // [])
    | map(select(
        ((.name // "") | ascii_downcase) == $label
        or ((.aliases // []) | map(ascii_downcase) | index($label) != null)
      ))
    | .[0].name // empty
  ')"
  [ -n "$name" ] || return 1
  printf '%s' "$name"
}

bf_sender_payer() {
  local uid="${TELEGRAM_BOTS_USER_ID:-}"
  if [ -n "$uid" ]; then
    local by_id
    by_id="$(bf_context | jq -r --argjson id "$uid" '
      (.payers // [])
      | map(select(.telegramId == $id or (.telegramId | tostring) == ($id | tostring)))
      | .[0].name // empty
    ' 2>/dev/null || true)"
    if [ -n "$by_id" ]; then
      printf '%s' "$by_id"
      return 0
    fi
  fi
  return 1
}

bf_payer_prompt() {
  bf_context | jq -r '
    (.payers // [])
    | map(
        (.name) as $n
        | ((.aliases // []) | map(select(. | ascii_downcase != ($n | ascii_downcase)))) as $extras
        | if ($extras | length) == 0 then $n
          else "\($n) (\($extras | join(", ")))"
          end
      )
    | join(", ")
  '
}

bf_bind_expense_payer() {
  local action_json="$1"
  local amount description payer share sender explicit resolved
  amount="$(printf '%s' "$action_json" | jq -r '.amount')"
  description="$(printf '%s' "$action_json" | jq -r '.description')"
  payer="$(printf '%s' "$action_json" | jq -r '.payer // empty')"
  share="$(printf '%s' "$action_json" | jq -r '.share // empty')"
  sender="$(bf_sender_payer || true)"

  if [ -n "$payer" ]; then
    explicit="$payer"
    resolved="$(bf_resolve_payer "$explicit")" || {
      echo "I don't know a payer named ${explicit}."
      return 1
    }
  else
    if [ -z "$sender" ]; then
      echo "I don't know whether this is Dan or Trotty."
      return 1
    fi
    resolved="$sender"
  fi

  if [ -n "$share" ]; then
    if [ -z "$sender" ]; then
      echo "I don't know who 'mine' is for that share note."
      return 1
    fi
    description="$(printf '%s' "$description" | sed 's/[[:space:]]*$//')"
    if [ -n "$description" ]; then
      description="${description}, \$${share} ${sender}"
    else
      description="\$${share} ${sender}"
    fi
  fi

  description="$(printf '%s' "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$description" ]; then
    echo "That expense needs a description."
    return 1
  fi

  jq -nc --arg amount "$amount" --arg description "$description" --arg payer "$resolved" \
    '{kind:"expense",amount:$amount,description:$description,payer:$payer}'
}

bf_summary() {
  local action_json="$1"
  local kind today
  kind="$(printf '%s' "$action_json" | jq -r '.kind')"
  today="$(bf_today)"
  case "$kind" in
    expense)
      jq -r --arg today "$today" '
        "Log expense?\nDate: \($today)\nAmount: \(.amount)\nPaid by: \(.payer)\nDescription: \(.description)"
      ' <<<"$action_json"
      ;;
    task)
      jq -r '
        if (.due // "") != "" then "Add task?\n\(.title)\nDue: \(.due)"
        else "Add task?\n\(.title)" end
      ' <<<"$action_json"
      ;;
    calendar)
      jq -r '"Add event?\n\(.summary)\n\(.start)\n\(.end)"' <<<"$action_json"
      ;;
    *)
      bf_die "unknown action kind: $kind"
      ;;
  esac
}

bf_perform() {
  local action_json="$1"
  local kind
  kind="$(printf '%s' "$action_json" | jq -r '.kind')"
  case "$kind" in
    expense)
      local amount description payer out
      amount="$(printf '%s' "$action_json" | jq -r '.amount')"
      description="$(printf '%s' "$action_json" | jq -r '.description')"
      payer="$(printf '%s' "$action_json" | jq -r '.payer')"
      out="$("${EXPENSES_SPREADSHEET}" add --paid-by "$payer" "$amount" "$description")"
      if [ -z "$out" ]; then
        echo "Logged ${amount} for ${payer}."
      else
        printf '%s\n' "$out"
      fi
      ;;
    task)
      local title due tasklist params body
      title="$(printf '%s' "$action_json" | jq -r '.title')"
      due="$(printf '%s' "$action_json" | jq -r '.due // empty')"
      tasklist="$(bf_ctx_get tasklist '@default')"
      params="$(jq -nc --arg tasklist "$tasklist" '{tasklist:$tasklist}')"
      if [ -n "$due" ]; then
        body="$(jq -nc --arg title "$title" --arg due "$due" '{title:$title,due:$due}')"
      else
        body="$(jq -nc --arg title "$title" '{title:$title}')"
      fi
      "${GWS}" tasks tasks insert --params "$params" --json "$body" >/dev/null
      echo "Added task: ${title}"
      ;;
    calendar)
      local summary start end calendar_id
      summary="$(printf '%s' "$action_json" | jq -r '.summary')"
      start="$(printf '%s' "$action_json" | jq -r '.start')"
      end="$(printf '%s' "$action_json" | jq -r '.end')"
      calendar_id="$(bf_ctx_get calendarId primary)"
      "${GWS}" calendar +insert --calendar "$calendar_id" \
        --summary "$summary" --start "$start" --end "$end" >/dev/null
      echo "Added ${summary}."
      ;;
    *)
      bf_die "unknown action kind: $kind"
      ;;
  esac
}

# Propose → confirm → perform. Prints result to stdout; cancel → empty stdout.
bf_confirm_perform() {
  local action_json="$1"
  local kind prepared summary choice
  kind="$(printf '%s' "$action_json" | jq -r '.kind')"
  if [ "$kind" = "expense" ]; then
    prepared="$(bf_bind_expense_payer "$action_json")" || {
      echo "$prepared"
      return 0
    }
    action_json="$prepared"
  fi
  summary="$(bf_summary "$action_json")"
  if ! choice="$(bf_ask "$summary")"; then
    return 0
  fi
  if [ "$choice" != "confirm" ]; then
    return 0
  fi
  bf_perform "$action_json"
}

# --- local parsers (parity with fam-telegram-bot commands.rs) ---

bf_is_payer_pronoun() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    i|we|he|she|they|someone|who) return 0 ;;
    *) return 1 ;;
  esac
}

# stdout: action JSON; stderr: parse error; return 1 on failure.
bf_parse_expense() {
  local text="$1"
  text="$(printf '%s' "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -n "$text" ] || { echo "expected an amount and a description" >&2; return 1; }

  local share="" payer="" amount="" rest="$text"

  # share: ($24- mine)
  if printf '%s' "$rest" | grep -qiE '\([[:space:]]*\$?[0-9]+(\.[0-9]+)?[[:space:]]*-[[:space:]]*mine[[:space:]]*\)'; then
    local shares
    shares="$(printf '%s' "$rest" | grep -oiE '\([[:space:]]*\$?[0-9]+(\.[0-9]+)?[[:space:]]*-[[:space:]]*mine[[:space:]]*\)' | wc -l)"
    if [ "$shares" -gt 1 ]; then
      echo "expected one share note" >&2
      return 1
    fi
    share="$(printf '%s' "$rest" | grep -oiE '\([[:space:]]*\$?[0-9]+(\.[0-9]+)?[[:space:]]*-[[:space:]]*mine[[:space:]]*\)' | head -1 \
      | sed -E 's/.*\$?([0-9]+(\.[0-9]+)?).*/\1/')"
    rest="$(printf '%s' "$rest" | sed -E 's/\([[:space:]]*\$?[0-9]+(\.[0-9]+)?[[:space:]]*-[[:space:]]*[Mm][Ii][Nn][Ee][[:space:]]*\)//')"
  fi

  # payer: "X paid" / "paid by X"
  local payer_match
  payer_match="$(printf '%s' "$rest" | grep -oiE '\b[A-Za-z]+[[:space:]]+paid\b|\bpaid[[:space:]]+by[[:space:]]+[A-Za-z]+\b' || true)"
  if [ -n "$payer_match" ]; then
    local count
    count="$(printf '%s\n' "$payer_match" | grep -c . || true)"
    if [ "$count" -gt 1 ]; then
      echo "expected one paid-by note" >&2
      return 1
    fi
    local who
    who="$(printf '%s' "$payer_match" | sed -E 's/[[:space:]]+paid$//;s/^paid[[:space:]]+by[[:space:]]+//I')"
    if ! bf_is_payer_pronoun "$who"; then
      payer="$who"
      # strip first occurrence (case-insensitive) of the paid phrase
      rest="$(printf '%s' "$rest" | sed -E "s/${payer_match}//I")"
    fi
  fi

  # amount
  local amounts
  amounts="$(printf '%s' "$rest" | grep -oE '\$?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?|\$?[0-9]+(\.[0-9]+)?' || true)"
  # filter alphanumeric boundaries roughly via checking neighbors — keep simple: all matches
  if [ -n "$amounts" ]; then
    local ac
    ac="$(printf '%s\n' "$amounts" | grep -c . || true)"
    if [ "$ac" -gt 1 ]; then
      echo "expected one amount" >&2
      return 1
    fi
    amount="$(printf '%s' "$amounts" | head -1 | tr -d '$,')"
    # remove first amount token
    rest="$(printf '%s' "$rest" | sed -E "s/\\\$?${amount//./\\.}//")"
  fi

  # description: drop amex tokens
  local description
  description="$(printf '%s' "$rest" | tr ',' ' ' | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | awk '{
        out=""
        for (i=1;i<=NF;i++) {
          if (tolower($i)=="amex") continue
          out = (out=="" ? $i : out " " $i)
        }
        print out
      }')"

  if [ -z "$amount" ]; then
    if [ -z "$description" ] && [ -z "$share" ]; then
      echo "expected a description" >&2
      return 1
    fi
    amount="0"
    if [ -z "$description" ]; then
      description="TODO"
    else
      description="TODO ${description}"
    fi
  elif [ -z "$description" ] && [ -z "$share" ]; then
    echo "expected a description" >&2
    return 1
  fi

  jq -nc \
    --arg amount "$amount" \
    --arg description "$description" \
    --arg payer "$payer" \
    --arg share "$share" \
    '{
      kind:"expense",
      amount:$amount,
      description:$description,
      payer:$payer
    } + (if $share == "" then {} else {share:$share} end)'
}

bf_task_implies_due() {
  printf '%s' "$1" | grep -qiE \
    '\b(today|tomorrow|tonight|monday|tuesday|wednesday|thursday|friday|saturday|sunday|next|due|by)\b|[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}|[0-9]{1,2}/[0-9]{1,2}(/[0-9]{2,4})?'
}

bf_parse_task() {
  local title="$1"
  title="$(printf '%s' "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$title" ]; then
    echo "expected \`/task <title>\`" >&2
    return 1
  fi
  if bf_task_implies_due "$title"; then
    echo "task looks dated; needs due-date interpretation" >&2
    return 1
  fi
  jq -nc --arg title "$title" '{kind:"task",title:$title}'
}

bf_parse_calendar() {
  local args="$1"
  local tz="${TELEGRAM_BOTS_TIMEZONE}"
  args="$(printf '%s' "$args" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if ! printf '%s' "$args" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+[0-9]{2}:[0-9]{2}'; then
    echo "expected \`/cal YYYY-MM-DD HH:MM [minutes] <summary>\`" >&2
    return 1
  fi
  local date time rest minutes=60 summary
  date="$(printf '%s' "$args" | awk '{print $1}')"
  time="$(printf '%s' "$args" | awk '{print $2}')"
  rest="$(printf '%s' "$args" | cut -d' ' -f3-)"
  if printf '%s' "$rest" | grep -qE '^[0-9]{1,4}[[:space:]]'; then
    minutes="$(printf '%s' "$rest" | awk '{print $1}')"
    summary="$(printf '%s' "$rest" | cut -d' ' -f2-)"
  else
    summary="$rest"
  fi
  summary="$(printf '%s' "$summary" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -n "$summary" ] || { echo "expected \`/cal YYYY-MM-DD HH:MM [minutes] <summary>\`" >&2; return 1; }

  local start_epoch end_epoch start end
  start_epoch="$(TZ="$tz" date -d "${date} ${time}" +%s)" || {
    echo "invalid date or time" >&2
    return 1
  }
  end_epoch=$((start_epoch + minutes * 60))
  start="$(TZ="$tz" date -d "@${start_epoch}" --iso-8601=seconds)"
  end="$(TZ="$tz" date -d "@${end_epoch}" --iso-8601=seconds)"
  jq -nc --arg summary "$summary" --arg start "$start" --arg end "$end" \
    '{kind:"calendar",summary:$summary,start:$start,end:$end}'
}

# cursor-agent → action JSON or clarify text on stdout with types via prefix.
# Prints: ACTION:<json> or CLARIFY:<text>
bf_interpret() {
  local forced_command="${1:-}" # expense|task|calendar|empty
  local text="$2"
  local parse_error="${3:-}"
  local tz="${TELEGRAM_BOTS_TIMEZONE}"
  local payers workspace sender prompt raw json
  payers="$(bf_payer_prompt)"
  [ -n "$payers" ] || payers="Dan, Trotty"
  workspace="$(bf_ctx_get workspace "${WORKSPACE:-}")"
  [ -n "$workspace" ] || workspace="${HOME}/repos/personal/dotfiles"
  sender="$(bf_sender_payer || true)"

  prompt="Turn this couple-chat admin message into one JSON object and nothing else. \
Do not call tools. action is expense, task, calendar, or none. \
expense needs amount (number as a string, 0 when the total is unknown) and description. \
There is no card column. A card name such as Amex is not part of the description. \
When the total is unknown, description starts with TODO. \
A note like (\$24- mine) is the sender's share of an unknown total: keep amount 0 unless another number is the total, and end the description with the share and the sender name. \
Known paid-by names: ${payers}. \
When the message says who paid (for example \"trotty paid\" or \"paid by dan\"), set payer to that name or alias and do not leave the paid-by phrase in the description. \
Omit payer when the message does not name who paid; the sender is assumed. \
task needs title and optional due as RFC3339 date in ${tz} (date-only midnight is fine). \
Include due when the message implies a day; omit due when there is no date. \
calendar needs summary, start, and end as RFC3339 in ${tz}. \
Resolve relative calendar dates (tomorrow, next Tuesday, Friday 3pm) in ${tz}. \
Default calendar duration is 60 minutes when unspecified. \
If a calendar message has no usable time, action is none. \
none needs reply, a short question asking for the missing detail. "

  if [ -n "$forced_command" ]; then
    prompt+="The user invoked /${forced_command}. action must be ${forced_command} or none. "
    if [ -n "$parse_error" ]; then
      prompt+="The programmatic parse failed: ${parse_error}. "
    fi
  fi
  if [ -n "$sender" ]; then
    prompt+="The sender is ${sender}. "
  fi
  prompt+="Message: ${text}"

  raw="$("${CURSOR_AGENT}" -p --mode ask --trust --workspace "$workspace" --output-format text "$prompt")" \
    || bf_die "cursor-agent failed"

  json="$(printf '%s' "$raw" | python3 -c '
import sys
raw = sys.stdin.read()
s = raw.find("{")
e = raw.rfind("}")
if s < 0 or e < s:
    raise SystemExit(1)
print(raw[s : e + 1])
')" || bf_die "cursor output contained no JSON"

  local action
  action="$(printf '%s' "$json" | jq -r '.action')"
  case "$action" in
    expense)
      local amount description payer
      amount="$(printf '%s' "$json" | jq -r 'if (.amount|type)=="number" then (.amount|tostring) else (.amount // empty) end')"
      description="$(printf '%s' "$json" | jq -r '.description // empty')"
      payer="$(printf '%s' "$json" | jq -r '.payer // empty')"
      [ -n "$amount" ] || bf_die "missing amount"
      [ -n "$description" ] || bf_die "missing description"
      if [ -n "$forced_command" ] && [ "$forced_command" != "expense" ]; then
        echo "CLARIFY:That /${forced_command} still needs the right details."
        return 0
      fi
      echo "ACTION:$(jq -nc --arg a "$amount" --arg d "$description" --arg p "$payer" \
        '{kind:"expense",amount:$a,description:$d,payer:$p}')"
      ;;
    task)
      local title due
      title="$(printf '%s' "$json" | jq -r '.title // empty')"
      due="$(printf '%s' "$json" | jq -r '.due // empty')"
      [ -n "$title" ] || bf_die "missing title"
      if [ -n "$forced_command" ] && [ "$forced_command" != "task" ]; then
        echo "CLARIFY:That /${forced_command} still needs the right details."
        return 0
      fi
      echo "ACTION:$(jq -nc --arg t "$title" --arg due "$due" \
        '{kind:"task",title:$t} + (if $due=="" then {} else {due:$due} end)')"
      ;;
    calendar)
      local summary start end
      summary="$(printf '%s' "$json" | jq -r '.summary // empty')"
      start="$(printf '%s' "$json" | jq -r '.start // empty')"
      end="$(printf '%s' "$json" | jq -r '.end // empty')"
      [ -n "$summary" ] || bf_die "missing summary"
      [ -n "$start" ] || bf_die "missing start"
      [ -n "$end" ] || bf_die "missing end"
      if [ -n "$forced_command" ] && [ "$forced_command" != "calendar" ]; then
        echo "CLARIFY:That /${forced_command} still needs the right details."
        return 0
      fi
      echo "ACTION:$(jq -nc --arg s "$summary" --arg a "$start" --arg e "$end" \
        '{kind:"calendar",summary:$s,start:$a,end:$e}')"
      ;;
    none)
      local reply
      reply="$(printf '%s' "$json" | jq -r '.reply // empty')"
      if [ -z "$reply" ]; then
        reply="Send one of:
/expense 15 coffee
/expense trotty paid 232.80 eye specialist
/expense Kmart
/task buy milk
/task buy milk tomorrow
/cal 2026-10-25 15:00 dentist
/cal 2026-10-25 15:00 90 dentist
/cal dentist tomorrow 3pm

Free-form also works — the assistant reads it, then you confirm before it is saved."
      fi
      echo "CLARIFY:${reply}"
      ;;
    *)
      bf_die "unknown action ${action}"
      ;;
  esac
}

bf_handle_forced() {
  local kind="$1" # expense|task|calendar
  shift
  local args="$*"
  local parsed err action_json interpreted

  args="$(printf '%s' "$args" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$args" ]; then
    case "$kind" in
      expense) echo "expected \`/expense <amount> <description>\` (e.g. /expense 15 coffee)" ;;
      task) echo "expected \`/task <title>\` (e.g. /task buy milk)" ;;
      calendar) echo "expected \`/cal YYYY-MM-DD HH:MM <summary>\`" ;;
      *) echo "expected arguments for /${kind}" ;;
    esac
    return 0
  fi

  local err_file
  err_file="$(mktemp)"
  set +e
  case "$kind" in
    expense) parsed="$(bf_parse_expense "$args" 2>"$err_file")" ;;
    task) parsed="$(bf_parse_task "$args" 2>"$err_file")" ;;
    calendar) parsed="$(bf_parse_calendar "$args" 2>"$err_file")" ;;
  esac
  local parse_rc=$?
  set -e
  err="$(cat "$err_file" 2>/dev/null || true)"
  rm -f "$err_file"

  if [ "$parse_rc" -eq 0 ] && [ -n "$parsed" ]; then
    bf_confirm_perform "$parsed"
    return 0
  fi

  interpreted="$(bf_interpret "$kind" "/${kind} ${args}" "$err")"
  case "$interpreted" in
    ACTION:*)
      action_json="${interpreted#ACTION:}"
      bf_confirm_perform "$action_json"
      ;;
    CLARIFY:*)
      printf '%s\n' "${interpreted#CLARIFY:}"
      ;;
    *)
      bf_die "unexpected interpret result"
      ;;
  esac
}

bf_handle_default() {
  local text="$*"
  text="$(printf '%s' "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$text" ]; then
    printf '%s\n' "Send one of:
/expense 15 coffee
/expense trotty paid 232.80 eye specialist
/expense Kmart
/task buy milk
/task buy milk tomorrow
/cal 2026-10-25 15:00 dentist
/cal 2026-10-25 15:00 90 dentist
/cal dentist tomorrow 3pm

Free-form also works — the assistant reads it, then you confirm before it is saved."
    return 0
  fi

  local interpreted action_json
  interpreted="$(bf_interpret "" "$text" "")"
  case "$interpreted" in
    ACTION:*)
      action_json="${interpreted#ACTION:}"
      bf_confirm_perform "$action_json"
      ;;
    CLARIFY:*)
      printf '%s\n' "${interpreted#CLARIFY:}"
      ;;
    *)
      bf_die "unexpected interpret result"
      ;;
  esac
}
