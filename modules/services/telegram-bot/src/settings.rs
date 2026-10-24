use std::fs;
use std::path::Path;

use serde::Deserialize;

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    pub payer: String,
    pub tasklist: String,
    pub timezone: String,
    pub spreadsheet_id: String,
    pub sheet_range: String,
    pub calendar_id: String,
    #[serde(default)]
    pub allowed_chat_ids: Vec<i64>,
    #[serde(default)]
    pub allowed_user_ids: Vec<i64>,
    pub workspace: String,
}

impl Settings {
    pub fn load(path: &Path) -> Result<Self, String> {
        let text = fs::read_to_string(path).map_err(|err| format!("reading settings: {err}"))?;
        serde_json::from_str(&text).map_err(|err| format!("parsing settings: {err}"))
    }
}
