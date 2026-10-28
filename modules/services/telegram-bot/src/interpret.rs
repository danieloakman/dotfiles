use std::path::PathBuf;
use std::time::Duration;

use serde::Deserialize;
use serde_json::Value;

use crate::action::Action;
use crate::commands::CommandKind;
use crate::proc;

/// Provider-neutral reading of one message. `cursor-agent` is the first backend.
pub trait Interpreter {
    fn interpret(&self, request: &InterpretRequest) -> Result<Interpreted, InterpretError>;
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct InterpretRequest {
    pub text: String,
    pub timezone: String,
    pub command: Option<CommandKind>,
    pub parse_error: Option<String>,
    pub sender: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Interpreted {
    Action(Action),
    Clarify(String),
}

#[derive(Debug)]
pub struct InterpretError {
    message: String,
}

impl InterpretError {
    fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl std::fmt::Display for InterpretError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.message)
    }
}

impl std::error::Error for InterpretError {}

pub struct CursorCliInterpreter {
    bin: PathBuf,
    workspace: PathBuf,
}

impl CursorCliInterpreter {
    pub fn new(bin: PathBuf, workspace: PathBuf) -> Self {
        Self { bin, workspace }
    }
}

impl Interpreter for CursorCliInterpreter {
    fn interpret(&self, request: &InterpretRequest) -> Result<Interpreted, InterpretError> {
        let mut command = std::process::Command::new(&self.bin);
        command.args(["-p", "--mode", "ask", "--trust", "--workspace"]);
        command.arg(&self.workspace);
        command.args(["--output-format", "text"]);
        command.arg(prompt(request));
        let output = proc::run(command, Duration::from_secs(180)).map_err(InterpretError::new)?;
        parse_model_output(&output.stdout)
    }
}

fn prompt(request: &InterpretRequest) -> String {
    let mut text = format!(
        "Turn this couple-chat admin message into one JSON object and nothing else. \
         Do not call tools. action is expense, task, calendar, or none. \
         expense needs amount (number as a string, 0 when the total is unknown) and description. \
         There is no card column. A card name such as Amex is not part of the description. \
         When the total is unknown, description starts with TODO. \
         A note like ($24- mine) is the sender's share of an unknown total: keep amount 0 unless another number is the total, and end the description with the share and the sender name. \
         task needs title. \
         calendar needs summary, start, and end as RFC3339 in {tz}. \
         none needs reply, a short question asking for the missing detail. ",
        tz = request.timezone,
    );
    if let Some(command) = request.command {
        text.push_str(&format!(
            "The user invoked /{name}. action must be {name} or none. ",
            name = command.as_str(),
        ));
        if let Some(error) = &request.parse_error {
            text.push_str(&format!("The programmatic parse failed: {error}. "));
        }
    }
    if !request.sender.is_empty() {
        text.push_str(&format!("The sender is {}. ", request.sender));
    }
    text.push_str("Message: ");
    text.push_str(&request.text);
    text
}

pub fn parse_model_output(raw: &str) -> Result<Interpreted, InterpretError> {
    let json = json_object(raw)?;
    let parsed: ModelJson = serde_json::from_str(json).map_err(|err| {
        InterpretError::new(format!("cursor output was not the expected JSON: {err}"))
    })?;
    match parsed.action.as_str() {
        "expense" => Ok(Interpreted::Action(Action::Expense {
            amount: amount(parsed.amount)?,
            description: required(parsed.description, "description")?,
            payer: String::new(),
            share: None,
        })),
        "task" => Ok(Interpreted::Action(Action::Task {
            title: required(parsed.title, "title")?,
        })),
        "calendar" => Ok(Interpreted::Action(Action::Calendar {
            summary: required(parsed.summary, "summary")?,
            start: required(parsed.start, "start")?,
            end: required(parsed.end, "end")?,
        })),
        "none" => Ok(Interpreted::Clarify(
            parsed
                .reply
                .filter(|reply| !reply.trim().is_empty())
                .unwrap_or_else(|| crate::route::help_text().to_string()),
        )),
        other => Err(InterpretError::new(format!("unknown action {other}"))),
    }
}

fn json_object(raw: &str) -> Result<&str, InterpretError> {
    let start = raw
        .find('{')
        .ok_or_else(|| InterpretError::new("cursor output contained no JSON"))?;
    let end = raw
        .rfind('}')
        .ok_or_else(|| InterpretError::new("cursor output contained no JSON"))?;
    if end < start {
        return Err(InterpretError::new("cursor output contained no JSON"));
    }
    Ok(&raw[start..=end])
}

fn required(value: Option<String>, field: &str) -> Result<String, InterpretError> {
    value
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| InterpretError::new(format!("missing {field}")))
}

fn amount(value: Option<Value>) -> Result<String, InterpretError> {
    match value {
        Some(Value::String(text)) if !text.trim().is_empty() => Ok(text),
        Some(Value::Number(number)) => Ok(number.to_string()),
        _ => Err(InterpretError::new("missing amount")),
    }
}

#[derive(Deserialize)]
struct ModelJson {
    action: String,
    amount: Option<Value>,
    description: Option<String>,
    title: Option<String>,
    summary: Option<String>,
    start: Option<String>,
    end: Option<String>,
    reply: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_json_wrapped_in_prose() {
        let raw = "Sure.\n{\"action\":\"task\",\"title\":\"buy milk\"}\nDone.";
        assert_eq!(
            parse_model_output(raw).unwrap(),
            Interpreted::Action(Action::Task {
                title: "buy milk".into(),
            })
        );
    }

    #[test]
    fn expense_amount_may_be_a_number() {
        let raw = r#"{"action":"expense","amount":15,"description":"coffee"}"#;
        match parse_model_output(raw).unwrap() {
            Interpreted::Action(Action::Expense {
                amount,
                description,
                ..
            }) => {
                assert_eq!(amount, "15");
                assert_eq!(description, "coffee");
            }
            other => panic!("expected expense, got {other:?}"),
        }
    }

    #[test]
    fn prompt_fixes_a_slash_command() {
        let request = InterpretRequest {
            text: "/expense buy milk".into(),
            timezone: "Australia/Sydney".into(),
            command: Some(CommandKind::Expense),
            parse_error: Some("expected one amount".into()),
            sender: "Trotty".into(),
        };
        let text = prompt(&request);
        assert!(text.contains("action must be expense or none"));
        assert!(text.contains("expected one amount"));
        assert!(text.contains("The sender is Trotty."));
        assert!(text.contains("Message: /expense buy milk"));
    }
}
