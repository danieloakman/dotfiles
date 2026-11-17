use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Condvar, Mutex};
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PendingAsk {
    pub id: String,
    pub role: String,
    pub chat_id: i64,
    pub message_id: i32,
    pub created: String,
}

pub struct AskWaiter {
    answer: Mutex<Option<Result<String, String>>>,
    cv: Condvar,
}

pub struct Shared {
    dir: PathBuf,
    offset: Mutex<Option<i64>>,
    /// message_id → ask id
    by_message: Mutex<HashMap<i32, String>>,
    pending: Mutex<HashMap<String, PendingAsk>>,
    waiters: Mutex<HashMap<String, Arc<AskWaiter>>>,
}

impl Shared {
    pub fn load(dir: &Path) -> Result<Arc<Self>, String> {
        fs::create_dir_all(dir).map_err(|err| format!("creating state dir: {err}"))?;
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
        Ok(Arc::new(Self {
            dir: dir.to_path_buf(),
            offset: Mutex::new(offset),
            by_message: Mutex::new(HashMap::new()),
            pending: Mutex::new(HashMap::new()),
            waiters: Mutex::new(HashMap::new()),
        }))
    }

    pub fn offset(&self) -> Option<i64> {
        *self.offset.lock().expect("offset lock")
    }

    pub fn set_offset(&self, offset: i64) -> Result<(), String> {
        *self.offset.lock().expect("offset lock") = Some(offset);
        fs::write(self.dir.join("offset"), offset.to_string())
            .map_err(|err| format!("writing offset: {err}"))
    }

    pub fn register_ask(&self, ask: PendingAsk) -> Arc<AskWaiter> {
        let waiter = Arc::new(AskWaiter {
            answer: Mutex::new(None),
            cv: Condvar::new(),
        });
        self.by_message
            .lock()
            .expect("by_message lock")
            .insert(ask.message_id, ask.id.clone());
        self.waiters
            .lock()
            .expect("waiters lock")
            .insert(ask.id.clone(), Arc::clone(&waiter));
        self.pending
            .lock()
            .expect("pending lock")
            .insert(ask.id.clone(), ask);
        waiter
    }

    pub fn complete_ask(&self, ask_id: &str, result: Result<String, String>) -> bool {
        let Some(waiter) = self.waiters.lock().expect("waiters lock").remove(ask_id) else {
            return false;
        };
        if let Some(ask) = self.pending.lock().expect("pending lock").remove(ask_id) {
            self.by_message
                .lock()
                .expect("by_message lock")
                .remove(&ask.message_id);
        }
        *waiter.answer.lock().expect("answer lock") = Some(result);
        waiter.cv.notify_all();
        true
    }

    pub fn ask_id_for_message(&self, message_id: i32) -> Option<String> {
        self.by_message
            .lock()
            .expect("by_message lock")
            .get(&message_id)
            .cloned()
    }

    pub fn latest_ask_id(&self) -> Option<String> {
        self.pending
            .lock()
            .expect("pending lock")
            .values()
            .max_by_key(|ask| ask.message_id)
            .map(|ask| ask.id.clone())
    }

    pub fn wait_for_answer(
        waiter: &AskWaiter,
        timeout: Duration,
    ) -> Result<String, String> {
        let deadline = Instant::now() + timeout;
        let mut guard = waiter.answer.lock().expect("answer lock");
        loop {
            if let Some(result) = guard.take() {
                return result;
            }
            let now = Instant::now();
            if now >= deadline {
                return Err("ask timed out".into());
            }
            let (next, wait_result) = waiter
                .cv
                .wait_timeout(guard, deadline - now)
                .expect("wait");
            guard = next;
            if wait_result.timed_out() {
                if let Some(result) = guard.take() {
                    return result;
                }
                return Err("ask timed out".into());
            }
        }
    }
}
