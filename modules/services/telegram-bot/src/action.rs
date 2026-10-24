use serde::{Deserialize, Serialize};

use crate::commands::CommandKind;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Action {
    Expense {
        card: String,
        amount: String,
        note: String,
    },
    Task {
        title: String,
    },
    Calendar {
        summary: String,
        start: String,
        end: String,
    },
}

impl Action {
    pub fn kind(&self) -> CommandKind {
        match self {
            Self::Expense { .. } => CommandKind::Expense,
            Self::Task { .. } => CommandKind::Task,
            Self::Calendar { .. } => CommandKind::Calendar,
        }
    }
}

pub fn summary(action: &Action, payer: &str, today: &str) -> String {
    match action {
        Action::Expense {
            card,
            amount,
            note,
        } => {
            let mut lines = vec![
                "Log expense?".to_string(),
                format!("Date: {today}"),
                format!("Card: {card}"),
                format!("Amount: {amount}"),
                format!("Payer: {payer}"),
            ];
            if !note.is_empty() {
                lines.push(format!("Note: {note}"));
            }
            lines.join("\n")
        }
        Action::Task { title } => format!("Add task?\n{title}"),
        Action::Calendar {
            summary,
            start,
            end,
        } => format!("Add event?\n{summary}\n{start}\n{end}"),
    }
}
