use std::sync::LazyLock;

use chrono::offset::TimeZone;
use chrono::{Duration, LocalResult, NaiveDateTime, SecondsFormat};
use chrono_tz::Tz;
use regex::Regex;

use crate::action::Action;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CommandKind {
    Expense,
    Task,
    Calendar,
}

impl CommandKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Expense => "expense",
            Self::Task => "task",
            Self::Calendar => "calendar",
        }
    }
}

pub fn timezone(name: &str) -> Result<Tz, String> {
    name.parse().map_err(|_| format!("unknown timezone {name}"))
}

pub fn parse_command(kind: CommandKind, args: &str, timezone_name: &str) -> Result<Action, String> {
    match kind {
        CommandKind::Expense => parse_expense(args),
        CommandKind::Task => parse_task(args),
        CommandKind::Calendar => parse_calendar(args, timezone_name),
    }
}

fn parse_expense(args: &str) -> Result<Action, String> {
    let args = args.trim();
    if args.is_empty() {
        return Err("expected an amount and a description".into());
    }
    let (share, rest) = extract_share(args)?;
    let (amount, rest) = extract_amount(&rest)?;
    let description = clean_description(&rest);
    if description.is_empty() && share.is_none() {
        return Err("expected a description".into());
    }
    let partial = amount.is_none();
    let description = if partial && description.is_empty() {
        "TODO".to_string()
    } else if partial {
        format!("TODO {description}")
    } else {
        description
    };
    Ok(Action::Expense {
        amount: amount.unwrap_or_else(|| "0".to_string()),
        description,
        payer: String::new(),
        share,
    })
}

/// `($24- mine)` is the sender's share, not the expense total.
fn extract_share(text: &str) -> Result<(Option<String>, String), String> {
    static SHARE: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"(?i)\(\s*\$?(?P<share>\d+(?:\.\d+)?)\s*-\s*mine\s*\)").expect("share regex")
    });
    let found: Vec<_> = SHARE.find_iter(text).collect();
    if found.len() > 1 {
        return Err("expected one share note".into());
    }
    let Some(found) = found.first() else {
        return Ok((None, text.to_string()));
    };
    let share = SHARE.captures(found.as_str()).expect("share capture")["share"].to_string();
    let mut rest = String::new();
    rest.push_str(&text[..found.start()]);
    rest.push_str(&text[found.end()..]);
    Ok((Some(share), rest))
}

fn extract_amount(text: &str) -> Result<(Option<String>, String), String> {
    static AMOUNT: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"\$?(?P<amount>\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)")
            .expect("amount regex")
    });
    let found: Vec<_> = AMOUNT
        .captures_iter(text)
        .filter(|caps| {
            let matched = caps.get(0).expect("amount match");
            amount_boundary(text, matched.start(), matched.end())
        })
        .collect();
    if found.len() > 1 {
        return Err("expected one amount".into());
    }
    let Some(caps) = found.first() else {
        return Ok((None, text.to_string()));
    };
    let matched = caps.get(0).expect("amount match");
    let amount = caps["amount"].replace(',', "");
    let mut rest = String::new();
    rest.push_str(&text[..matched.start()]);
    rest.push_str(&text[matched.end()..]);
    Ok((Some(amount), rest))
}

fn amount_boundary(text: &str, start: usize, end: usize) -> bool {
    let prev_ok = text[..start]
        .chars()
        .next_back()
        .is_none_or(|ch| !ch.is_alphanumeric());
    let next_ok = text[end..]
        .chars()
        .next()
        .is_none_or(|ch| !ch.is_alphanumeric());
    prev_ok && next_ok
}

/// The sheet has no card column. Amex is how a payment is mentioned, not a description.
fn clean_description(text: &str) -> String {
    text.split_whitespace()
        .filter(|word| !word.eq_ignore_ascii_case("amex"))
        .collect::<Vec<_>>()
        .join(" ")
}

fn parse_task(args: &str) -> Result<Action, String> {
    let title = args.trim();
    if title.is_empty() {
        return Err("expected `/task <title>`".into());
    }
    Ok(Action::Task {
        title: title.to_string(),
    })
}

fn parse_calendar(args: &str, timezone_name: &str) -> Result<Action, String> {
    static CAL: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(
            r"^(?P<date>\d{4}-\d{2}-\d{2})\s+(?P<time>\d{2}:\d{2})(?:\s+(?P<minutes>\d{1,4}))?\s+(?P<summary>.+)$",
        )
        .expect("calendar regex")
    });
    let Some(caps) = CAL.captures(args.trim()) else {
        return Err("expected `/cal YYYY-MM-DD HH:MM [minutes] <summary>`".into());
    };
    let tz = timezone(timezone_name)?;
    let naive = NaiveDateTime::parse_from_str(
        &format!("{} {}", &caps["date"], &caps["time"]),
        "%Y-%m-%d %H:%M",
    )
    .map_err(|_| "invalid date or time".to_string())?;
    let start = match tz.from_local_datetime(&naive) {
        LocalResult::Single(dt) => dt,
        LocalResult::Ambiguous(earlier, _) => earlier,
        LocalResult::None => return Err("that local time does not exist".into()),
    };
    let minutes = match caps.name("minutes") {
        Some(value) => value
            .as_str()
            .parse::<i64>()
            .map_err(|_| "invalid duration".to_string())?,
        None => 60,
    };
    let end = start + Duration::minutes(minutes);
    Ok(Action::Calendar {
        summary: caps["summary"].trim().to_string(),
        start: start.to_rfc3339_opts(SecondsFormat::Secs, false),
        end: end.to_rfc3339_opts(SecondsFormat::Secs, false),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn expense_amount_is_any_number_and_the_rest_is_the_description() {
        assert_eq!(
            parse_command(CommandKind::Expense, "$15 coffee", "Australia/Sydney").unwrap(),
            Action::Expense {
                amount: "15".into(),
                description: "coffee".into(),
                payer: String::new(),
                share: None,
            }
        );
        assert_eq!(
            parse_command(CommandKind::Expense, "lunch 20.50", "Australia/Sydney").unwrap(),
            Action::Expense {
                amount: "20.50".into(),
                description: "lunch".into(),
                payer: String::new(),
                share: None,
            }
        );
    }

    #[test]
    fn expense_without_a_total_is_a_todo() {
        assert_eq!(
            parse_command(CommandKind::Expense, "Kmart Amex", "Australia/Sydney").unwrap(),
            Action::Expense {
                amount: "0".into(),
                description: "TODO Kmart".into(),
                payer: String::new(),
                share: None,
            }
        );
        assert_eq!(
            parse_command(
                CommandKind::Expense,
                "Kmart Amex ($24- mine)",
                "Australia/Sydney",
            )
            .unwrap(),
            Action::Expense {
                amount: "0".into(),
                description: "TODO Kmart".into(),
                payer: String::new(),
                share: Some("24".into()),
            }
        );
    }

    #[test]
    fn expense_with_two_amounts_is_left_for_the_assistant() {
        assert!(parse_command(CommandKind::Expense, "10 coffee 2", "Australia/Sydney").is_err());
    }

    #[test]
    fn task_requires_a_title() {
        assert_eq!(
            parse_command(CommandKind::Task, "buy milk", "Australia/Sydney").unwrap(),
            Action::Task {
                title: "buy milk".into(),
            }
        );
        assert!(parse_command(CommandKind::Task, "  ", "Australia/Sydney").is_err());
    }

    #[test]
    fn calendar_defaults_to_one_hour() {
        match parse_command(
            CommandKind::Calendar,
            "2026-10-25 15:00 dentist",
            "Australia/Sydney",
        )
        .unwrap()
        {
            Action::Calendar {
                summary,
                start,
                end,
            } => {
                assert_eq!(summary, "dentist");
                assert_eq!(start, "2026-10-25T15:00:00+11:00");
                assert_eq!(end, "2026-10-25T16:00:00+11:00");
            }
            other => panic!("expected calendar, got {other:?}"),
        }
        match parse_command(
            CommandKind::Calendar,
            "2026-10-25 15:00 90 long visit",
            "Australia/Sydney",
        )
        .unwrap()
        {
            Action::Calendar { end, .. } => assert_eq!(end, "2026-10-25T16:30:00+11:00"),
            other => panic!("expected calendar, got {other:?}"),
        }
    }
}
