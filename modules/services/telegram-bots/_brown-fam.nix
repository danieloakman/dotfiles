# BrownFam command runners for telegram-bots (expenses / tasks / calendar / default).
{ lib
, pkgs
, writeShellApplication
, expensesSpreadsheet
, gwsExe
, cursorAgentExe
, telegramBotsExe
, credentialsFile
}:
let
  libSh = ./_lib.sh;

  mkRunner = { name, body }: writeShellApplication {
    inherit name;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.jq
      pkgs.python3
    ];
    text = ''
      set -euo pipefail
      # shellcheck disable=SC1091
      source ${libSh}
      export EXPENSES_SPREADSHEET=${lib.escapeShellArg expensesSpreadsheet}
      export GWS=${lib.escapeShellArg gwsExe}
      export GWS_BIN=${lib.escapeShellArg gwsExe}
      export CURSOR_AGENT=${lib.escapeShellArg cursorAgentExe}
      export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=${lib.escapeShellArg credentialsFile}
      # Prefer absolute telegram-bots for ask (daemon PATH may be minimal).
      export PATH=${lib.escapeShellArg (builtins.dirOf telegramBotsExe)}:$PATH
      ${body}
    '';
  };
in
{
  expense = mkRunner {
    name = "brown-fam-expense";
    body = ''bf_handle_forced expense "$@" '';
  };
  task = mkRunner {
    name = "brown-fam-task";
    body = ''bf_handle_forced task "$@" '';
  };
  cal = mkRunner {
    name = "brown-fam-cal";
    body = ''bf_handle_forced calendar "$@" '';
  };
  default = mkRunner {
    name = "brown-fam-default";
    body = ''bf_handle_default "$@" '';
  };
}
