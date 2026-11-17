use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::Path;
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use serde::{Deserialize, Serialize};

use crate::service::App;
use crate::state::Shared;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
pub enum Request {
    Send {
        text: String,
        #[serde(default)]
        role: Option<String>,
    },
    Ask {
        text: String,
        #[serde(default)]
        role: Option<String>,
        #[serde(default = "default_timeout")]
        timeout_sec: u64,
    },
    Ping,
}

fn default_timeout() -> u64 {
    600
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Response {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message_id: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ask_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub answer: Option<String>,
}

impl Response {
    fn ok_send(message_id: i32) -> Self {
        Self {
            ok: true,
            error: None,
            message_id: Some(message_id),
            ask_id: None,
            answer: None,
        }
    }

    fn ok_ask(ask_id: String, answer: String) -> Self {
        Self {
            ok: true,
            error: None,
            message_id: None,
            ask_id: Some(ask_id),
            answer: Some(answer),
        }
    }

    fn err(msg: impl Into<String>) -> Self {
        Self {
            ok: false,
            error: Some(msg.into()),
            message_id: None,
            ask_id: None,
            answer: None,
        }
    }
}

pub fn listen(socket: &Path, app: Arc<App>, state: Arc<Shared>) -> Result<(), String> {
    if socket.exists() {
        std::fs::remove_file(socket).map_err(|err| format!("removing old socket: {err}"))?;
    }
    if let Some(parent) = socket.parent() {
        std::fs::create_dir_all(parent).map_err(|err| format!("creating socket dir: {err}"))?;
    }
    let listener =
        UnixListener::bind(socket).map_err(|err| format!("binding control socket: {err}"))?;
    // Allow the same user (and root via runuser) to connect.
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(socket, std::fs::Permissions::from_mode(0o660));
    }
    log::info!("control socket listening on {}", socket.display());

    loop {
        match listener.accept() {
            Ok((stream, _)) => {
                let app = Arc::clone(&app);
                let state = Arc::clone(&state);
                thread::spawn(move || {
                    if let Err(err) = handle_client(stream, &app, &state) {
                        log::error!("ipc client failed: {err}");
                    }
                });
            }
            Err(err) => {
                log::error!("accept failed: {err}");
                thread::sleep(Duration::from_secs(1));
            }
        }
    }
}

fn handle_client(stream: UnixStream, app: &App, state: &Shared) -> Result<(), String> {
    let mut reader = BufReader::new(stream.try_clone().map_err(|e| e.to_string())?);
    let mut line = String::new();
    reader
        .read_line(&mut line)
        .map_err(|err| format!("reading request: {err}"))?;
    if line.trim().is_empty() {
        return Ok(());
    }
    let request: Request =
        serde_json::from_str(line.trim()).map_err(|err| format!("parsing request: {err}"))?;
    let response = match request {
        Request::Ping => Response {
            ok: true,
            error: None,
            message_id: None,
            ask_id: None,
            answer: None,
        },
        Request::Send { text, role } => match app.send(role.as_deref(), &text) {
            Ok(message_id) => Response::ok_send(message_id),
            Err(err) => Response::err(err),
        },
        Request::Ask {
            text,
            role,
            timeout_sec,
        } => match app.ask(role.as_deref(), &text, Duration::from_secs(timeout_sec), state)
        {
            Ok((ask_id, answer)) => Response::ok_ask(ask_id, answer),
            Err(err) => Response::err(err),
        },
    };
    let mut writer = stream;
    let body = serde_json::to_string(&response).map_err(|e| e.to_string())?;
    writeln!(writer, "{body}").map_err(|err| format!("writing response: {err}"))?;
    Ok(())
}

pub fn call(socket: &Path, request: &Request) -> Result<Response, String> {
    let mut stream = UnixStream::connect(socket)
        .map_err(|err| format!("connecting to {}: {err}", socket.display()))?;
    let body = serde_json::to_string(request).map_err(|e| e.to_string())?;
    writeln!(stream, "{body}").map_err(|err| format!("writing request: {err}"))?;
    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    reader
        .read_line(&mut line)
        .map_err(|err| format!("reading response: {err}"))?;
    serde_json::from_str(line.trim()).map_err(|err| format!("parsing response: {err}"))
}
