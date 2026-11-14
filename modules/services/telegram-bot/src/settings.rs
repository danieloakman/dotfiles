use std::fs;
use std::path::Path;

use serde::Deserialize;

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Payer {
    pub name: String,
    #[serde(default)]
    pub telegram_id: Option<i64>,
    #[serde(default)]
    pub aliases: Vec<String>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    pub tasklist: String,
    pub timezone: String,
    pub calendar_id: String,
    #[serde(default)]
    pub allowed_chat_ids: Vec<i64>,
    #[serde(default)]
    pub allowed_user_ids: Vec<i64>,
    pub workspace: String,
    #[serde(default)]
    pub payers: Vec<Payer>,
}

impl Settings {
    pub fn load(path: &Path) -> Result<Self, String> {
        let text = fs::read_to_string(path).map_err(|err| format!("reading settings: {err}"))?;
        serde_json::from_str(&text).map_err(|err| format!("parsing settings: {err}"))
    }

    /// Canonical Paid-by name for a name or alias, if known.
    /// Matching is case-insensitive and ignores a leading `@` (Telegram usernames).
    pub fn resolve_payer(&self, label: &str) -> Option<&str> {
        let label = normalize_payer_label(label);
        if label.is_empty() {
            return None;
        }
        for person in &self.payers {
            if normalize_payer_label(&person.name) == label
                || person
                    .aliases
                    .iter()
                    .any(|alias| normalize_payer_label(alias) == label)
            {
                return Some(person.name.as_str());
            }
        }
        None
    }

    /// Short list for the interpreter prompt, e.g. `Dan (Daniel), Trotty (Sheridan)`.
    pub fn payer_prompt(&self) -> String {
        self.payers
            .iter()
            .map(|person| {
                let extras: Vec<&str> = person
                    .aliases
                    .iter()
                    .map(String::as_str)
                    .filter(|alias| !alias.eq_ignore_ascii_case(&person.name))
                    .collect();
                if extras.is_empty() {
                    person.name.clone()
                } else {
                    format!("{} ({})", person.name, extras.join(", "))
                }
            })
            .collect::<Vec<_>>()
            .join(", ")
    }
}

fn normalize_payer_label(label: &str) -> String {
    label.trim().trim_start_matches('@').to_ascii_lowercase()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn settings() -> Settings {
        Settings {
            tasklist: "@default".into(),
            timezone: "Australia/Sydney".into(),
            calendar_id: "primary".into(),
            allowed_chat_ids: vec![],
            allowed_user_ids: vec![],
            workspace: "/tmp".into(),
            payers: vec![
                Payer {
                    name: "Dan".into(),
                    telegram_id: Some(1),
                    aliases: vec!["Dan".into(), "Daniel".into()],
                },
                Payer {
                    name: "Trotty".into(),
                    telegram_id: Some(2),
                    aliases: vec!["Trotty".into(), "Sheridan".into()],
                },
            ],
        }
    }

    #[test]
    fn resolve_payer_matches_name_and_alias_case_insensitively() {
        let settings = settings();
        assert_eq!(settings.resolve_payer("dan"), Some("Dan"));
        assert_eq!(settings.resolve_payer("DANIEL"), Some("Dan"));
        assert_eq!(settings.resolve_payer("@Daniel"), Some("Dan"));
        assert_eq!(settings.resolve_payer("sheridan"), Some("Trotty"));
        assert_eq!(settings.resolve_payer("@SHERIDAN"), Some("Trotty"));
        assert_eq!(settings.resolve_payer("tRoTtY"), Some("Trotty"));
        assert_eq!(settings.resolve_payer("nobody"), None);
    }
}
