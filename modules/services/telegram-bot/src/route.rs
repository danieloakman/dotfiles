use crate::action::Action;
use crate::commands::{self, CommandKind};
use crate::interpret::{InterpretError, InterpretRequest, Interpreted, Interpreter};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Decision {
    Help,
    Action(Action),
    Clarify(String),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Prepared {
    Help,
    Action(Action),
    Model(InterpretRequest),
}

pub fn help_text() -> &'static str {
    "Send one of:\n\
     /expense amex 15 coffee\n\
     /task buy milk\n\
     /cal 2026-10-25 15:00 dentist\n\
     /cal 2026-10-25 15:00 90 dentist\n\
     \n\
     Anything else is read by the assistant, then confirmed before it is saved."
}

pub fn plan(
    text: &str,
    reply: Option<&str>,
    timezone: &str,
    shortcut: &dyn Fn(&str) -> Option<Action>,
) -> Prepared {
    plan_text(&command_text(text, reply), timezone, shortcut)
}

pub fn route(
    text: &str,
    reply: Option<&str>,
    timezone: &str,
    shortcut: &dyn Fn(&str) -> Option<Action>,
    interpreter: &dyn Interpreter,
) -> Result<Decision, InterpretError> {
    match plan(text, reply, timezone, shortcut) {
        Prepared::Help => Ok(Decision::Help),
        Prepared::Action(action) => Ok(Decision::Action(action)),
        Prepared::Model(request) => {
            let interpreted = interpreter.interpret(&request)?;
            Ok(apply(interpreted, &request))
        }
    }
}

pub fn apply(interpreted: Interpreted, request: &InterpretRequest) -> Decision {
    match (request.command, interpreted) {
        (Some(forced), Interpreted::Action(action)) if action.kind() != forced => {
            Decision::Clarify(format!(
                "That /{} still needs the right details.",
                forced.as_str()
            ))
        }
        (_, Interpreted::Action(action)) => Decision::Action(action),
        (_, Interpreted::Clarify(text)) => Decision::Clarify(text),
    }
}

fn plan_text(
    text: &str,
    timezone: &str,
    shortcut: &dyn Fn(&str) -> Option<Action>,
) -> Prepared {
    let text = text.trim();
    if text.is_empty() {
        return Prepared::Help;
    }
    if let Some((name, args)) = split_slash(text) {
        match name.as_str() {
            "help" => return Prepared::Help,
            "start" if args.is_empty() => return Prepared::Help,
            "start" => return plan_text(args, timezone, shortcut),
            "expense" => {
                return finish_parse(CommandKind::Expense, args, text, timezone);
            }
            "task" => return finish_parse(CommandKind::Task, args, text, timezone),
            "cal" | "calendar" => {
                return finish_parse(CommandKind::Calendar, args, text, timezone);
            }
            _ => {}
        }
    }
    if let Some(action) = shortcut(text) {
        return Prepared::Action(action);
    }
    Prepared::Model(InterpretRequest {
        text: text.to_string(),
        timezone: timezone.to_string(),
        command: None,
        parse_error: None,
    })
}

fn finish_parse(kind: CommandKind, args: &str, text: &str, timezone: &str) -> Prepared {
    match commands::parse_command(kind, args, timezone) {
        Ok(action) => Prepared::Action(action),
        Err(error) => Prepared::Model(InterpretRequest {
            text: text.to_string(),
            timezone: timezone.to_string(),
            command: Some(kind),
            parse_error: Some(error),
        }),
    }
}

fn split_slash(text: &str) -> Option<(String, &str)> {
    let rest = text.trim().strip_prefix('/')?;
    let (token, args) = match rest.split_once(char::is_whitespace) {
        Some((token, args)) => (token, args.trim()),
        None => (rest, ""),
    };
    if token.is_empty() {
        return None;
    }
    let name = token.split('@').next().unwrap_or(token);
    Some((name.to_ascii_lowercase(), args))
}

pub fn command_text(text: &str, reply: Option<&str>) -> String {
    let stripped = strip_mentions(text);
    let stripped = stripped.trim();
    if stripped.is_empty() {
        reply.unwrap_or("").trim().to_string()
    } else {
        stripped.to_string()
    }
}

/// Drop `@name` tokens that start a message or follow whitespace.
/// `/expense@Bot` keeps the suffix so the command splitter can remove it.
fn strip_mentions(text: &str) -> String {
    let mut out = String::new();
    let mut chars = text.chars().peekable();
    let mut boundary = true;
    while let Some(ch) = chars.next() {
        if ch == '@' && boundary {
            while chars
                .peek()
                .is_some_and(|next| next.is_alphanumeric() || *next == '_')
            {
                chars.next();
            }
            continue;
        }
        out.push(ch);
        boundary = ch.is_whitespace();
    }
    out
}

#[cfg(test)]
mod tests {
    use std::cell::RefCell;

    use super::*;
    use crate::interpret::Interpreted;

    struct Fake {
        calls: RefCell<Vec<InterpretRequest>>,
        result: Interpreted,
    }

    impl Interpreter for Fake {
        fn interpret(&self, request: &InterpretRequest) -> Result<Interpreted, InterpretError> {
            self.calls.borrow_mut().push(request.clone());
            Ok(self.result.clone())
        }
    }

    fn no_shortcut(_text: &str) -> Option<Action> {
        None
    }

    fn fake(result: Interpreted) -> Fake {
        Fake {
            calls: RefCell::new(Vec::new()),
            result,
        }
    }

    #[test]
    fn valid_slash_skips_the_interpreter() {
        let interpreter = fake(Interpreted::Action(Action::Task {
            title: "nope".into(),
        }));
        let decision = route(
            "@secretary /expense amex $15",
            None,
            "Australia/Sydney",
            &no_shortcut,
            &interpreter,
        )
        .unwrap();
        assert_eq!(
            decision,
            Decision::Action(Action::Expense {
                card: "amex".into(),
                amount: "15".into(),
                note: String::new(),
            })
        );
        assert!(interpreter.calls.borrow().is_empty());
    }

    #[test]
    fn invalid_slash_fixes_that_command() {
        let interpreter = fake(Interpreted::Action(Action::Expense {
            card: "amex".into(),
            amount: "15".into(),
            note: "milk".into(),
        }));
        let decision = route(
            "/expense buy milk",
            None,
            "Australia/Sydney",
            &no_shortcut,
            &interpreter,
        )
        .unwrap();
        assert!(matches!(decision, Decision::Action(Action::Expense { .. })));
        let calls = interpreter.calls.borrow();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].command, Some(CommandKind::Expense));
        assert!(calls[0].parse_error.is_some());
    }

    #[test]
    fn forced_command_rejects_a_different_action() {
        let interpreter = fake(Interpreted::Action(Action::Task {
            title: "buy milk".into(),
        }));
        let decision = route(
            "/expense buy milk",
            None,
            "Australia/Sydney",
            &no_shortcut,
            &interpreter,
        )
        .unwrap();
        assert_eq!(
            decision,
            Decision::Clarify("That /expense still needs the right details.".into())
        );
    }

    #[test]
    fn shortcut_skips_the_interpreter() {
        let interpreter = fake(Interpreted::Clarify("nope".into()));
        let decision = route(
            "milk",
            None,
            "Australia/Sydney",
            &|text| {
                (text == "milk").then(|| Action::Task {
                    title: "buy milk".into(),
                })
            },
            &interpreter,
        )
        .unwrap();
        assert_eq!(
            decision,
            Decision::Action(Action::Task {
                title: "buy milk".into(),
            })
        );
        assert!(interpreter.calls.borrow().is_empty());
    }

    #[test]
    fn free_text_is_unconstrained() {
        let interpreter = fake(Interpreted::Clarify("Which card?".into()));
        let decision = route(
            "amex 15",
            None,
            "Australia/Sydney",
            &no_shortcut,
            &interpreter,
        )
        .unwrap();
        assert_eq!(decision, Decision::Clarify("Which card?".into()));
        let calls = interpreter.calls.borrow();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].command, None);
        assert_eq!(calls[0].text, "amex 15");
    }

    #[test]
    fn reply_is_used_when_the_mention_has_no_other_text() {
        let interpreter = fake(Interpreted::Clarify("unused".into()));
        let decision = route(
            "@secretary",
            Some("/task buy milk"),
            "Australia/Sydney",
            &no_shortcut,
            &interpreter,
        )
        .unwrap();
        assert_eq!(
            decision,
            Decision::Action(Action::Task {
                title: "buy milk".into(),
            })
        );
        assert!(interpreter.calls.borrow().is_empty());
    }

    #[test]
    fn help_and_start_do_not_call_the_interpreter() {
        let interpreter = fake(Interpreted::Clarify("nope".into()));
        assert_eq!(
            route("/help", None, "Australia/Sydney", &no_shortcut, &interpreter).unwrap(),
            Decision::Help
        );
        assert_eq!(
            route("/start", None, "Australia/Sydney", &no_shortcut, &interpreter).unwrap(),
            Decision::Help
        );
        assert_eq!(
            route(
                "/start /task buy milk",
                None,
                "Australia/Sydney",
                &no_shortcut,
                &interpreter,
            )
            .unwrap(),
            Decision::Action(Action::Task {
                title: "buy milk".into(),
            })
        );
        assert!(interpreter.calls.borrow().is_empty());
    }

    #[test]
    fn command_suffix_is_still_a_local_command() {
        let interpreter = fake(Interpreted::Clarify("nope".into()));
        let decision = route(
            "/expense@BrownFamBot amex 15",
            None,
            "Australia/Sydney",
            &no_shortcut,
            &interpreter,
        )
        .unwrap();
        assert_eq!(
            decision,
            Decision::Action(Action::Expense {
                card: "amex".into(),
                amount: "15".into(),
                note: String::new(),
            })
        );
        assert!(interpreter.calls.borrow().is_empty());
    }
}
