use std::path::PathBuf;

use chrono::Utc;
use chrono_tz::Tz;
use frankenstein::types::{CallbackQuery, ChatType, MaybeInaccessibleMessage, Message, User};
use frankenstein::updates::{Update, UpdateContent};

use crate::action::{self, Action};
use crate::gws;
use crate::interpret::{CursorCliInterpreter, Interpreter};
use crate::route::{self, Decision, Prepared};
use crate::settings::Settings;
use crate::shortcuts;
use crate::state::{Pending, State, Status};
use crate::telegram::{self, EditTarget, Telegram};

pub struct Service {
    settings: Settings,
    tz: Tz,
    telegram: Telegram,
    state: State,
    gws: PathBuf,
    expenses: PathBuf,
    interpreter: CursorCliInterpreter,
}

impl Service {
    pub fn new(
        settings: Settings,
        tz: Tz,
        telegram: Telegram,
        state: State,
        gws: PathBuf,
        expenses: PathBuf,
        interpreter: CursorCliInterpreter,
    ) -> Self {
        Self {
            settings,
            tz,
            telegram,
            state,
            gws,
            expenses,
            interpreter,
        }
    }

    pub fn run(&mut self) -> Result<(), String> {
        log::info!("polling private chats and guest mentions");
        loop {
            if let Err(err) = self.poll_once() {
                log::error!("poll failed: {err}");
                std::thread::sleep(std::time::Duration::from_secs(5));
            }
        }
    }

    fn poll_once(&mut self) -> Result<(), String> {
        let updates = self.telegram.updates(self.state.offset())?;
        for update in updates {
            let next = i64::from(update.update_id) + 1;
            if let Err(err) = self.handle(update) {
                log::error!("update failed: {err}");
            }
            self.state.set_offset(next)?;
        }
        Ok(())
    }

    fn handle(&mut self, update: Update) -> Result<(), String> {
        match update.content {
            UpdateContent::GuestMessage(message) => self.handle_guest(*message),
            UpdateContent::Message(message) => self.handle_private(*message),
            UpdateContent::CallbackQuery(callback) => self.handle_callback(*callback),
            _ => Ok(()),
        }
    }

    fn handle_guest(&mut self, message: Message) -> Result<(), String> {
        let Some(query_id) = message.guest_query_id.clone() else {
            log::info!("guest message without guest_query_id");
            return Ok(());
        };
        let chat_id = message.chat.id;
        let user_id = message.from.as_ref().map(|user| user.id);
        log::info!("guest chat_id={chat_id} user_id={}", user_label(user_id));
        let origin = Origin::Guest {
            query_id: query_id.clone(),
        };
        if !self.allowed(chat_id, user_id) {
            self.telegram.answer_guest(
                &query_id,
                "This chat is not allowed to use the secretary.",
                None,
            )?;
            return Ok(());
        }
        self.dispatch(origin, chat_id, user_id, &message)
    }

    fn handle_private(&mut self, message: Message) -> Result<(), String> {
        if message.chat.type_field != ChatType::Private {
            return Ok(());
        }
        if message.from.as_ref().is_some_and(|user| user.is_bot) {
            return Ok(());
        }
        let chat_id = message.chat.id;
        let user_id = message.from.as_ref().map(|user| user.id);
        log::info!("private chat_id={chat_id} user_id={}", user_label(user_id));
        if !self.allowed(chat_id, user_id) {
            self.telegram.send(
                chat_id,
                "This chat is not allowed to use the secretary.",
                None,
            )?;
            return Ok(());
        }
        self.dispatch(Origin::Private { chat_id }, chat_id, user_id, &message)
    }

    fn dispatch(
        &mut self,
        origin: Origin,
        chat_id: i64,
        user_id: Option<u64>,
        message: &Message,
    ) -> Result<(), String> {
        let user = message.from.as_deref();
        let own = message
            .text
            .as_deref()
            .or(message.caption.as_deref())
            .unwrap_or("");
        let reply = message
            .reply_to_message
            .as_ref()
            .and_then(|reply| reply.text.as_deref().or(reply.caption.as_deref()));
        let prepared = route::plan(
            own,
            reply,
            &self.settings.timezone,
            &shortcuts::match_shortcut,
        );
        match prepared {
            Prepared::Help => {
                self.reply(&origin, Outgoing::New, route::help_text(), None)?;
                Ok(())
            }
            Prepared::Action(action) => {
                self.propose_action(origin, chat_id, user_id, user, Outgoing::New, action)
            }
            Prepared::Model(mut request) => {
                if let Some(name) = payer_name(&self.settings, user) {
                    request.sender = name;
                }
                let target = self.reply(&origin, Outgoing::New, "Working on it…", None)?;
                match self.interpreter.interpret(&request) {
                    Ok(interpreted) => match route::apply(interpreted, &request) {
                        Decision::Help => {
                            self.reply(&origin, Outgoing::Edit(target), route::help_text(), None)?;
                        }
                        Decision::Clarify(text) => {
                            self.reply(&origin, Outgoing::Edit(target), &text, None)?;
                        }
                        Decision::Action(action) => {
                            self.propose_action(
                                origin,
                                chat_id,
                                user_id,
                                user,
                                Outgoing::Edit(target),
                                action,
                            )?;
                        }
                    },
                    Err(err) => {
                        log::error!("interpreter failed: {err}");
                        self.reply(
                            &origin,
                            Outgoing::Edit(target),
                            &format!("Could not read that.\n{err}"),
                            None,
                        )?;
                    }
                }
                Ok(())
            }
        }
    }

    fn propose_action(
        &mut self,
        origin: Origin,
        chat_id: i64,
        user_id: Option<u64>,
        user: Option<&User>,
        outgoing: Outgoing,
        action: Action,
    ) -> Result<(), String> {
        let action = match prepare_action(&self.settings, action, user) {
            Ok(action) => action,
            Err(text) => {
                self.reply(&origin, outgoing, &text, None)?;
                return Ok(());
            }
        };
        self.propose(origin, chat_id, user_id, outgoing, action)
    }

    fn propose(
        &mut self,
        origin: Origin,
        chat_id: i64,
        user_id: Option<u64>,
        outgoing: Outgoing,
        action: Action,
    ) -> Result<(), String> {
        let today = Utc::now().with_timezone(&self.tz).format("%Y-%m-%d");
        let text = action::summary(&action, &today.to_string());
        let action_id = self.state.new_id()?;
        let target = self.reply(
            &origin,
            outgoing,
            &text,
            Some(telegram::buttons(&action_id)),
        )?;
        let (inline_message_id, reply_chat_id, reply_message_id) = match &target {
            EditTarget::Inline(id) => (Some(id.clone()), None, None),
            EditTarget::Chat {
                chat_id,
                message_id,
            } => (None, Some(*chat_id), Some(*message_id)),
        };
        self.state.insert(
            action_id,
            Pending {
                action,
                chat_id: Some(chat_id),
                user_id,
                inline_message_id,
                reply_chat_id,
                reply_message_id,
                status: Status::Pending,
            },
        )
    }

    fn reply(
        &self,
        origin: &Origin,
        outgoing: Outgoing,
        text: &str,
        markup: Option<frankenstein::types::InlineKeyboardMarkup>,
    ) -> Result<EditTarget, String> {
        match outgoing {
            Outgoing::New => match origin {
                Origin::Guest { query_id } => self.telegram.answer_guest(query_id, text, markup),
                Origin::Private { chat_id } => self.telegram.send(*chat_id, text, markup),
            },
            Outgoing::Edit(target) => {
                self.telegram.edit(&target, text, markup)?;
                Ok(target)
            }
        }
    }

    fn handle_callback(&mut self, callback: CallbackQuery) -> Result<(), String> {
        let data = callback.data.clone().unwrap_or_default();
        let Some((confirm, action_id)) = parse_callback(&data) else {
            self.telegram.answer_callback(&callback.id, None)?;
            return Ok(());
        };
        let Some(mut record) = self.state.get(&action_id).cloned() else {
            self.telegram
                .answer_callback(&callback.id, Some("That confirmation expired."))?;
            return Ok(());
        };
        if record
            .user_id
            .is_some_and(|owner| owner != callback.from.id)
        {
            self.telegram
                .answer_callback(&callback.id, Some("Only the person who asked can confirm."))?;
            return Ok(());
        }
        let target = callback_target(&record, &callback);
        if !confirm {
            self.state.remove(&action_id)?;
            self.telegram
                .answer_callback(&callback.id, Some("Cancelled."))?;
            if let Some(target) = target {
                self.telegram
                    .edit(&target, "Cancelled.", Some(telegram::empty_keyboard()))?;
            }
            return Ok(());
        }
        if record.status == Status::Running {
            self.telegram
                .answer_callback(&callback.id, Some("Already saving."))?;
            return Ok(());
        }
        record.status = Status::Running;
        self.state.insert(action_id.clone(), record.clone())?;
        self.telegram
            .answer_callback(&callback.id, Some("Saving…"))?;
        match gws::perform(&self.gws, &self.expenses, &self.settings, &record.action) {
            Ok(result) => {
                self.state.remove(&action_id)?;
                if let Some(target) = target {
                    self.telegram
                        .edit(&target, &result, Some(telegram::empty_keyboard()))?;
                }
            }
            Err(err) => {
                log::error!("save failed: {err}");
                record.status = Status::Pending;
                self.state.insert(action_id.clone(), record)?;
                if let Some(target) = target {
                    self.telegram.edit(
                        &target,
                        &format!("Failed.\n{err}"),
                        Some(telegram::buttons(&action_id)),
                    )?;
                }
            }
        }
        Ok(())
    }

    fn allowed(&self, chat_id: i64, user_id: Option<u64>) -> bool {
        if !self.settings.allowed_chat_ids.is_empty()
            && !self.settings.allowed_chat_ids.contains(&chat_id)
        {
            return false;
        }
        if self.settings.allowed_user_ids.is_empty() {
            return true;
        }
        user_id
            .and_then(|id| i64::try_from(id).ok())
            .is_some_and(|id| self.settings.allowed_user_ids.contains(&id))
    }
}

enum Origin {
    Guest { query_id: String },
    Private { chat_id: i64 },
}

enum Outgoing {
    New,
    Edit(EditTarget),
}

fn callback_target(record: &Pending, callback: &CallbackQuery) -> Option<EditTarget> {
    if let Some(id) = &record.inline_message_id {
        return Some(EditTarget::Inline(id.clone()));
    }
    if let Some(message) = &callback.message {
        return Some(match message {
            MaybeInaccessibleMessage::Message(message) => EditTarget::Chat {
                chat_id: message.chat.id,
                message_id: message.message_id,
            },
            MaybeInaccessibleMessage::InaccessibleMessage(message) => EditTarget::Chat {
                chat_id: message.chat.id,
                message_id: message.message_id,
            },
        });
    }
    match (record.reply_chat_id, record.reply_message_id) {
        (Some(chat_id), Some(message_id)) => Some(EditTarget::Chat {
            chat_id,
            message_id,
        }),
        _ => None,
    }
}

fn parse_callback(data: &str) -> Option<(bool, String)> {
    let (verb, id) = data.split_once(':')?;
    if id.is_empty() {
        return None;
    }
    match verb {
        "c" => Some((true, id.to_string())),
        "x" => Some((false, id.to_string())),
        _ => None,
    }
}

fn prepare_action(
    settings: &Settings,
    action: Action,
    user: Option<&User>,
) -> Result<Action, String> {
    if !matches!(action, Action::Expense { .. }) {
        return Ok(action);
    }
    let payer = payer_name(settings, user).ok_or_else(|| unknown_payer(user))?;
    action::bind_payer(action, &payer)
}

fn payer_name(settings: &Settings, user: Option<&User>) -> Option<String> {
    let user = user?;
    let id = i64::try_from(user.id).ok();
    for person in &settings.payers {
        if person.telegram_id.is_some() && person.telegram_id == id {
            return Some(person.name.clone());
        }
    }
    let labels = [
        Some(user.first_name.as_str()),
        user.last_name.as_deref(),
        user.username.as_deref(),
    ];
    for label in labels.into_iter().flatten() {
        for person in &settings.payers {
            if person.name.eq_ignore_ascii_case(label)
                || person
                    .aliases
                    .iter()
                    .any(|alias| alias.eq_ignore_ascii_case(label))
            {
                return Some(person.name.clone());
            }
        }
    }
    None
}

fn unknown_payer(user: Option<&User>) -> String {
    match user {
        Some(user) => {
            let shown = user.username.as_deref().unwrap_or(user.first_name.as_str());
            format!(
                "I don't know whether {shown} ({}) is Dan or Trotty.",
                user.id
            )
        }
        None => "I don't know whether this is Dan or Trotty.".into(),
    }
}

fn user_label(user_id: Option<u64>) -> String {
    user_id
        .map(|id| id.to_string())
        .unwrap_or_else(|| "-".to_string())
}
