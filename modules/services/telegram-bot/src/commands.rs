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
    name.parse()
        .map_err(|_| format!("unknown timezone {name}"))
}

pub fn parse_command(kind: CommandKind, args: &str, timezone_name: &str) -> Result<Action, String> {
    match kind {
        CommandKind::Expense => parse_expense(args),
        CommandKind::Task => parse_task(args),
        CommandKind::Calendar => parse_calendar(args, timezone_name),
    }
}

fn parse_expense(args: &str) -> Result<Action, String> {
    static EXPENSE: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(
            r"^(?P<card>[A-Za-z][\w-]*)\s+\$?(?P<amount>\d+(?:\.\d{1,2})?)\b\s*(?P<note>.*)$",
        )
        .expect("expense regex")
    });
    let Some(caps) = EXPENSE.captures(args.trim()) else {
        return Err("expected `/expense <card> <amount> [note]`".into());
    };
    Ok(Action::Expense {
        card: caps["card"].to_string(),
        amount: caps["amount"].to_string(),
        note: caps["note"].trim().to_string(),
    })
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
    fn expense_amount_and_note() {
        assert_eq!(
            parse_command(CommandKind::Expense, "amex $15", "Australia/Sydney").unwrap(),
            Action::Expense {
                card: "amex".into(),
                amount: "15".into(),
                note: String::new(),
            }
        );
        match parse_command(CommandKind::Expense, "Visa 20.50 lunch", "Australia/Sydney").unwrap()
        {
            Action::Expense { note, .. } => assert_eq!(note, "lunch"),
            other => panic!("expected expense, got {other:?}"),
        }
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
            Action::Calendar { summary, start, end } => {
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
