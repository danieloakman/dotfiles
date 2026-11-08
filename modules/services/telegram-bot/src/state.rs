use std::collections::HashMap;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::action::Action;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Status {
    Pending,
    Running,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Pending {
    pub action: Action,
    #[serde(default)]
    pub chat_id: Option<i64>,
    #[serde(default)]
    pub user_id: Option<u64>,
    #[serde(default)]
    pub inline_message_id: Option<String>,
    #[serde(default)]
    pub reply_chat_id: Option<i64>,
    #[serde(default)]
    pub reply_message_id: Option<i32>,
    pub status: Status,
}

pub struct State {
    dir: PathBuf,
    pending: HashMap<String, Pending>,
    offset: Option<i64>,
}

impl State {
    pub fn load(dir: &Path) -> Result<Self, String> {
        fs::create_dir_all(dir).map_err(|err| format!("creating state dir: {err}"))?;
        let pending_path = dir.join("pending.json");
        let pending = if pending_path.exists() {
            let text = fs::read_to_string(&pending_path)
                .map_err(|err| format!("reading pending confirmations: {err}"))?;
            serde_json::from_str(&text)
                .map_err(|err| format!("parsing pending confirmations: {err}"))?
        } else {
            HashMap::new()
        };
        let offset_path = dir.join("offset");
        let offset = if offset_path.exists() {
            let text =
                fs::read_to_string(&offset_path).map_err(|err| format!("reading offset: {err}"))?;
            let text = text.trim();
            if text.is_empty() {
                None
            } else {
                Some(
                    text.parse::<i64>()
                        .map_err(|err| format!("parsing offset: {err}"))?,
                )
            }
        } else {
            None
        };
        let mut state = Self {
            dir: dir.to_path_buf(),
            pending,
            offset,
        };
        state.reset_running()?;
        Ok(state)
    }

    pub fn offset(&self) -> Option<i64> {
        self.offset
    }

    pub fn set_offset(&mut self, offset: i64) -> Result<(), String> {
        self.offset = Some(offset);
        atomic_write(&self.dir.join("offset"), offset.to_string().as_bytes())
            .map_err(|err| format!("saving offset: {err}"))
    }

    pub fn get(&self, id: &str) -> Option<&Pending> {
        self.pending.get(id)
    }

    pub fn insert(&mut self, id: String, pending: Pending) -> Result<(), String> {
        self.pending.insert(id, pending);
        self.save()
    }

    pub fn remove(&mut self, id: &str) -> Result<(), String> {
        self.pending.remove(id);
        self.save()
    }

    pub fn new_id(&self) -> Result<String, String> {
        for _ in 0..8 {
            let id = random_id()?;
            if !self.pending.contains_key(&id) {
                return Ok(id);
            }
        }
        Err("could not allocate a confirmation id".into())
    }

    fn reset_running(&mut self) -> Result<(), String> {
        let mut changed = false;
        for pending in self.pending.values_mut() {
            if pending.status == Status::Running {
                pending.status = Status::Pending;
                changed = true;
            }
        }
        if changed {
            self.save()?;
        }
        Ok(())
    }

    fn save(&self) -> Result<(), String> {
        let bytes = serde_json::to_vec(&self.pending).map_err(|err| err.to_string())?;
        atomic_write(&self.dir.join("pending.json"), &bytes)
            .map_err(|err| format!("saving pending confirmations: {err}"))
    }
}

fn random_id() -> Result<String, String> {
    let mut bytes = [0u8; 4];
    let mut file =
        fs::File::open("/dev/urandom").map_err(|err| format!("opening urandom: {err}"))?;
    file.read_exact(&mut bytes)
        .map_err(|err| format!("reading urandom: {err}"))?;
    Ok(bytes.iter().map(|byte| format!("{byte:02x}")).collect())
}

fn atomic_write(path: &Path, bytes: &[u8]) -> std::io::Result<()> {
    let tmp = path.with_extension("tmp");
    fs::write(&tmp, bytes)?;
    fs::rename(tmp, path)
}
