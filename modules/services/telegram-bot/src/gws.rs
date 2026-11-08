use std::path::Path;
use std::time::Duration;

use crate::action::Action;
use crate::proc;
use crate::settings::Settings;

pub fn perform(
    gws: &Path,
    expenses: &Path,
    settings: &Settings,
    action: &Action,
) -> Result<String, String> {
    match action {
        Action::Expense {
            amount,
            description,
            payer,
            ..
        } => append_expense(expenses, payer, amount, description),
        Action::Task { title } => insert_task(gws, settings, title),
        Action::Calendar {
            summary,
            start,
            end,
        } => insert_event(gws, settings, summary, start, end),
    }
}

fn append_expense(
    expenses: &Path,
    payer: &str,
    amount: &str,
    description: &str,
) -> Result<String, String> {
    let mut command = std::process::Command::new(expenses);
    command.args(["add", "--paid-by", payer, amount, description]);
    let output = proc::run(command, Duration::from_secs(60))?;
    let text = output.stdout.trim();
    if text.is_empty() {
        Ok(format!("Logged {amount} for {payer}."))
    } else {
        Ok(text.to_string())
    }
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
            "tasks", "tasks", "insert", "--params", &params, "--json", &body,
        ],
    )?;
    Ok(format!("Added task: {title}"))
}

fn run<'a>(gws: &Path, args: impl IntoIterator<Item = &'a str>) -> Result<(), String> {
    let mut command = std::process::Command::new(gws);
    command.args(args);
    proc::run(command, Duration::from_secs(60)).map(|_| ())
}
