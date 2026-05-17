import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  // TODO: add sorting via plugin settings:
  property var passEntries: []

  function refreshEntries() {
    passListProc.running = true;
  }

  IpcHandler {
    target: "plugin:pass-menu"

    function toggle() {
      if (!pluginApi) return;
      pluginApi.withCurrentScreen(screen => {
        pluginApi.toggleLauncher(screen);
      });
    }
  }

  Process {
    id: passListProc

    running: false
    // TODO: add using passwordStoreDir from plugin settings:
    command: [
      "zsh",
      "-c",
      "store=\"${PASSWORD_STORE_DIR:-$HOME/.password-store}\"; find \"$store\" -type f -name '*.gpg' 2>/dev/null | sed \"s|^$store/||\" | sed 's/\\.gpg$//' | sort",
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        var text = this.text || "";
        root.passEntries = text.split("\n").filter(function (line) {
          return line.length > 0;
        });
      }
    }
  }
}
