# Settings for general developer tools and other related things that only apply to using the system as a developer.

{ pkgs, lib, config, env, ... }:
let
  cfg = config.my.programs.dev-pkgs;

  port-kill = pkgs.writeShellScriptBin "port-kill" ''
    exec ${lib.getExe pkgs.killport} "$@"
  '';

  # Local SSH port forward to a Tailscale host (e.g. `port-fwd mara 8080`).
  # Each port is forwarded 1:1 (localhost:<port> -> <host>:<port>).
  port-fwd = pkgs.writeShellScriptBin "port-fwd" ''
    set -euo pipefail

    SSH=${lib.getExe pkgs.openssh}

    usage() {
      local code="''${1:-1}"
      echo "Usage: port-fwd <host> <port> [port...]" >&2
      echo "  port-fwd mara 8080           # localhost:8080 -> mara:8080" >&2
      echo "  port-fwd mara 5173 8080      # both ports, same on each side" >&2
      echo "" >&2
      echo "Options:" >&2
      echo "  -h, --help                   Show this help" >&2
      exit "$code"
    }

    [ $# -ge 1 ] || usage
    case "$1" in
      -h|--help) usage 0 ;;
    esac
    [ $# -ge 2 ] || usage

    host="$1"
    shift

    forwards=()
    for port in "$@"; do
      case "$port" in
        -h|--help) usage 0 ;;
        *[!0-9]*|"") echo "Invalid port: $port" >&2; exit 1 ;;
      esac
      forwards+=(-L "''${port}:localhost:''${port}")
      echo "Forwarding localhost:$port -> $host:$port"
    done
    echo "(Ctrl-C to stop)"

    # LogLevel=ERROR hides the INFO spam when a client hits the local
    # forward before anything is listening on the remote port:
    #   channel N: open failed: connect failed: ... connection refused
    exec "$SSH" -N \
      -o ExitOnForwardFailure=yes \
      -o LogLevel=ERROR \
      "''${forwards[@]}" \
      "$host"
  '';

  # ss only shows a short process name; this resolves PIDs to full executable + args.
  port-ls = pkgs.writeShellScriptBin "port-ls" ''
    set -euo pipefail

    SS=${lib.getExe' pkgs.iproute2 "ss"}
    PS=${lib.getExe' pkgs.procps "ps"}

    usage() {
      local code="''${1:-1}"
      echo "Usage: port-ls [port...]" >&2
      echo "  port-ls              # list all listening TCP/UDP ports" >&2
      echo "  port-ls 8080 5173    # list listeners on those ports" >&2
      echo "" >&2
      echo "Options:" >&2
      echo "  -h, --help           Show this help" >&2
      exit "$code"
    }

    for arg in "$@"; do
      case "$arg" in
        -h|--help) usage 0 ;;
      esac
    done

    extract_pid() {
      sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p'
    }

    extract_port() {
      local addr="$1"
      addr="''${addr#[}"
      addr="''${addr%]}"
      echo "''${addr##*:}" | sed 's/,.*//'
    }

    print_listeners() {
      local proto="$1"
      shift

      while IFS= read -r line; do
        [ -z "$line" ] && continue

        local port pid user cmd
        port="$(extract_port "$(awk '{print $4}' <<< "$line")")"
        pid="$(extract_pid <<< "$line")"
        user="?"
        cmd="?"
        if [ -n "$pid" ]; then
          user="$("$PS" -o user= -p "$pid" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
          cmd="$("$PS" -ww -o args= -p "$pid" 2>/dev/null | sed 's/^[[:space:]]*//')"
          [ -n "$user" ] || user="?"
          [ -n "$cmd" ] || cmd="?"
        fi
        if [ "$found" -eq 0 ]; then
          printf '%-5s %-6s %-8s %s\n' "PORT" "PID" "USER" "COMMAND"
          found=1
        fi
        printf '%-5s %-6s %-8s %s\n' "$port/$proto" "''${pid:-?}" "$user" "$cmd"
      done < <("$SS" -H "$@" 2>/dev/null || true)
    }

    found=0

    if [ $# -eq 0 ]; then
      print_listeners tcp -tlnp
      print_listeners udp -ulnp
      if [ "$found" -eq 0 ]; then
        echo "No processes listening."
      fi
      exit 0
    fi

    for port_num in "$@"; do
      case "$port_num" in
        *[!0-9]*|"") echo "Invalid port: $port_num" >&2; usage ;;
      esac
      print_listeners tcp -tlnp "sport = :$port_num"
      print_listeners udp -ulnp "sport = :$port_num"
    done

    if [ "$found" -eq 0 ]; then
      if [ $# -eq 1 ]; then
        echo "No process listening on port $1."
      else
        echo "No processes listening on ports: $*."
      fi
    fi
  '';
in
{
  options.my.programs.dev-pkgs.enable = lib.mkEnableOption "Enable and include developer packages in the system environment";

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      my.programs.antigravity-cli.enable = true;
      my.programs.micro.enable = true;
    }
    (env.selectPlatform {
      any = {
        environment.systemPackages = with pkgs; [
          nixpkgs-fmt
          statix
          nil
          nodejs_24
          bun
          pnpm
          pnpm-shell-completion
          pet # CLI tool for keeping a list of commands and executing them later
          entr
          ripgrep # We could use the home-manager ripgrep package instead if we needed to give it some specific arguments everytime
          just # Task runner, like `make`
          just-lsp # LSP for Just files
          fd # A better `find` command
          port-kill # Kill processes listening on a port
          port-fwd # SSH local port forward to a Tailscale host
          dust # A better `du` command. Just prints out size of directories in the CWD
          zbar # Can scan QR & bar codes using this
          awscli2
          mprocs
          uv # Python package manager; can install packages and run them adhoc
          pandoc # Document converter
          rtk # More efficient token usage for LLMs
          defuddle # Extract clean HTML/markdown/metadata from web pages

          # Golang & related tools:
          go
          gopls
          delve

          llmfit # CLI tool to find what LLMs can run on our hardware
          libnotify # Add `notify-send` command
          ghostscript
          tesseract
        ];
      };
      linux = {
        environment.systemPackages = with pkgs; [
          # rclone # Don't need anymore as it was just used for Obsidian syncing
          gnat13 # Provides gcc, g++, etc
          # libgcc # Unsure why this doesn't gives gcc, g++, etc as programs to use, but it don't
          gnumake
          nurl # Generates nix fetcher urls
          ncdu # Similar to `dust`, but provides a UI to delete directories
          tldr
          wine # For running Windows applications on Linux
          nix-prefetch-github

          # yarn

          # OpenJDK 21 (as of time of this comment):
          zulu
          jre8

          # Fly.io control:
          flyctl

          port-ls # List processes listening on a port, with full executable + args

          # Editors that can be ssh'd into and used:
          vscode
        ];
      };

      darwin = {
        environment.systemPackages = with pkgs; [
          mas # Mac App Store CLI
          cocoapods
        ];
      };
    })
  ]);
}
