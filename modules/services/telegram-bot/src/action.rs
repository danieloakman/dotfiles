use serde::{Deserialize, Serialize};

use crate::commands::CommandKind;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Action {
    Expense {
        amount: String,
        description: String,
        payer: String,
        /// Sender's share from `($24- mine)`. Folded into the description once the payer is known.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        share: Option<String>,
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

pub fn summary(action: &Action, today: &str) -> String {
    match action {
        Action::Expense {
            amount,
            description,
            payer,
            ..
        } => {
            format!(
                "Log expense?\nDate: {today}\nAmount: {amount}\nPaid by: {payer}\nDescription: {description}"
            )
        }
        Action::Task { title } => format!("Add task?\n{title}"),
        Action::Calendar {
            summary,
            start,
            end,
        } => format!("Add event?\n{summary}\n{start}\n{end}"),
    }
}

/// Fill in who paid. A share note becomes `, $24 Trotty` on the description.
pub fn bind_payer(action: Action, payer: &str) -> Result<Action, String> {
    match action {
        Action::Expense {
            amount,
            description,
            share,
            ..
        } => {
            if payer.trim().is_empty() {
                return Err("I don't know whether this is Dan or Trotty.".into());
            }
            let description = append_share(description, share.as_deref(), payer);
            if description.trim().is_empty() {
                return Err("That expense needs a description.".into());
            }
            Ok(Action::Expense {
                amount,
                description,
                payer: payer.to_string(),
                share: None,
            })
        }
        other => Ok(other),
    }
}

fn append_share(description: String, share: Option<&str>, payer: &str) -> String {
    let mut description = description.trim().to_string();
    let Some(share) = share else {
        return description;
    };
    if !description.is_empty() {
        description.push_str(", ");
    }
    description.push_str(&format!("${share} {payer}"));
    description
}
