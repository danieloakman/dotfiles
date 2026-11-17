use std::fs;
use std::path::Path;

use serde::Deserialize;

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    /// Destination chats for send/ask (usually a single private chat with Dan).
    pub chat_ids: Vec<i64>,
    /// Users allowed to answer asks. Empty allows every user in those chats.
    #[serde(default)]
    pub allowed_user_ids: Vec<i64>,
}

impl Settings {
    pub fn load(path: &Path) -> Result<Self, String> {
        let text = fs::read_to_string(path).map_err(|err| format!("reading settings: {err}"))?;
        let settings: Self =
            serde_json::from_str(&text).map_err(|err| format!("parsing settings: {err}"))?;
        if settings.chat_ids.is_empty() {
            return Err("settings.chatIds must be non-empty".into());
        }
        Ok(settings)
    }

    pub fn allows_user(&self, user_id: Option<u64>) -> bool {
        if self.allowed_user_ids.is_empty() {
            return true;
        }
        let Some(uid) = user_id else {
            return false;
        };
        self.allowed_user_ids
            .iter()
            .any(|allowed| *allowed == uid as i64)
    }
}
