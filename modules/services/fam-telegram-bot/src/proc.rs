use std::process::{Command, Output, Stdio};
use std::time::Duration;

pub struct ProcOutput {
    pub stdout: String,
}

pub fn run(mut command: Command, timeout: Duration) -> Result<ProcOutput, String> {
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        command.process_group(0);
    }
    command.stdout(Stdio::piped()).stderr(Stdio::piped());
    let child = command
        .spawn()
        .map_err(|err| format!("failed to start process: {err}"))?;
    let pid = child.id();
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let _ = tx.send(child.wait_with_output());
    });
    match rx.recv_timeout(timeout) {
        Ok(Ok(output)) => finish(output),
        Ok(Err(err)) => Err(err.to_string()),
        Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
            let _ = Command::new("kill")
                .args(["-KILL", "--", &format!("-{pid}")])
                .status();
            let _ = rx.recv_timeout(Duration::from_secs(2));
            Err(format!("timed out after {}s", timeout.as_secs()))
        }
        Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
            Err("process waiter stopped".into())
        }
    }
}

fn finish(output: Output) -> Result<ProcOutput, String> {
    let stdout = String::from_utf8_lossy(&output.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).into_owned();
    if output.status.success() {
        return Ok(ProcOutput { stdout });
    }
    let detail = if stderr.trim().is_empty() {
        stdout.trim()
    } else {
        stderr.trim()
    };
    if detail.is_empty() {
        let code = output
            .status
            .code()
            .map(|code| code.to_string())
            .unwrap_or_else(|| "signal".into());
        Err(format!("process exited {code}"))
    } else {
        Err(detail.to_string())
    }
}
