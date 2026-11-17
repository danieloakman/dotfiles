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
        #[serde(default, skip_serializing_if = "Option::is_none")]
        due: Option<String>,
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
        Action::Task { title, due } => match due {
            Some(due) => format!("Add task?\n{title}\nDue: {due}"),
            None => format!("Add task?\n{title}"),
        },
        Action::Calendar {
            summary,
            start,
            end,
        } => format!("Add event?\n{summary}\n{start}\n{end}"),
    }
}

/// Fill in who paid. A `($24- mine)` share is attributed to `share_as` (the sender),
/// which may differ from `payer` when the message says someone else paid.
pub fn bind_payer(action: Action, payer: &str, share_as: Option<&str>) -> Result<Action, String> {
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
            let description = match share.as_deref() {
                Some(share) => {
                    let who = share_as.ok_or_else(|| {
                        "I don't know who 'mine' is for that share note.".to_string()
                    })?;
                    append_share(description, share, who)
                }
                None => description.trim().to_string(),
            };
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

fn append_share(description: String, share: &str, who: &str) -> String {
    let mut description = description.trim().to_string();
    if !description.is_empty() {
        description.push_str(", ");
    }
    description.push_str(&format!("${share} {who}"));
    description
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn share_note_uses_sender_not_payer() {
        let action = Action::Expense {
            amount: "0".into(),
            description: "TODO Kmart".into(),
            payer: String::new(),
            share: Some("24".into()),
        };
        let bound = bind_payer(action, "Trotty", Some("Dan")).unwrap();
        assert_eq!(
            bound,
            Action::Expense {
                amount: "0".into(),
                description: "TODO Kmart, $24 Dan".into(),
                payer: "Trotty".into(),
                share: None,
            }
        );
    }
}
