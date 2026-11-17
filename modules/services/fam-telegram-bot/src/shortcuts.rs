use crate::action::Action;

/// Deterministic readings for short messages that have no slash command.
/// Phrase rules land here and run before the interpreter.
pub fn match_shortcut(_text: &str) -> Option<Action> {
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shortcut_table_starts_empty() {
        assert_eq!(match_shortcut("amex 15"), None);
        assert_eq!(match_shortcut("buy milk"), None);
    }
}
