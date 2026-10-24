use std::path::Path;
use std::time::Duration;

use chrono::Utc;
use chrono_tz::Tz;

use crate::action::Action;
use crate::proc;
use crate::settings::Settings;

pub fn perform(gws: &Path, settings: &Settings, tz: Tz, action: &Action) -> Result<String, String> {
    match action {
        Action::Expense { card, amount, note } => {
            append_expense(gws, settings, tz, card, amount, note)
        }
        Action::Task { title } => insert_task(gws, settings, title),
        Action::Calendar { summary, start, end } => {
            insert_event(gws, settings, summary, start, end)
        }
    }
}

fn append_expense(
    gws: &Path,
    settings: &Settings,
    tz: Tz,
    card: &str,
    amount: &str,
    note: &str,
) -> Result<String, String> {
    if settings.spreadsheet_id.is_empty() {
        return Err("spreadsheet-id is not set".into());
    }
    let today = Utc::now()
        .with_timezone(&tz)
        .format("%Y-%m-%d")
        .to_string();
    let row = vec![
        today,
        card.to_string(),
        amount.to_string(),
        settings.payer.clone(),
        note.to_string(),
    ];
    let values = serde_json::to_string(&vec![row]).map_err(|err| err.to_string())?;
    run(
        gws,
        [
            "sheets",
            "+append",
            "--spreadsheet",
            &settings.spreadsheet_id,
            "--range",
            &settings.sheet_range,
            "--json-values",
            &values,
        ],
    )?;
    Ok(format!("Logged {card} {amount} as {}.", settings.payer))
}

fn insert_event(
    gws: &Path,
    settings: &Settings,
    summary: &str,
    start: &str,
    end: &str,
) -> Result<String, String> {
    run(
        gws,
        [
            "calendar",
            "+insert",
            "--calendar",
            &settings.calendar_id,
            "--summary",
            summary,
            "--start",
            start,
            "--end",
            end,
        ],
    )?;
    Ok(format!("Added {summary}."))
}

fn insert_task(gws: &Path, settings: &Settings, title: &str) -> Result<String, String> {
    let params = serde_json::json!({ "tasklist": settings.tasklist }).to_string();
    let body = serde_json::json!({ "title": title }).to_string();
    run(
        gws,
        [
            "tasks",
            "tasks",
            "insert",
            "--params",
            &params,
            "--json",
            &body,
        ],
    )?;
    Ok(format!("Added task: {title}"))
}

fn run<'a>(gws: &Path, args: impl IntoIterator<Item = &'a str>) -> Result<(), String> {
    let mut command = std::process::Command::new(gws);
    command.args(args);
    proc::run(command, Duration::from_secs(60)).map(|_| ())
}
