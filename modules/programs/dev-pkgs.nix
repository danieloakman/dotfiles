# Settings for general developer tools and other related things that only apply to using the system as a developer.

{ pkgs, lib, config, env, ... }:
let
  cfg = config.my.programs.devPkgs;

  # ss only shows a short process name; this resolves PIDs to full executable + args.
  showport = pkgs.writeShellScriptBin "showport" ''
    set -euo pipefail

    SS=${lib.getExe' pkgs.iproute2 "ss"}
    PS=${lib.getExe' pkgs.procps "ps"}

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
  options.my.programs.devPkgs.enable = lib.mkEnableOption "Enable and include developer packages in the system environment";

  config = lib.mkIf cfg.enable (
    {
      my.programs.antigravity-cli.enable = true;
      my.programs.micro.enable = true;
    }
    // env.selectPlatform {
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
          just-lsp # LSP for Just files
          fd # A better `find` command
          killport # Kill processes listening on a port

          # Golang & related tools:
          go
          gopls
          delve

          llmfit # CLI tool to find what LLMs can run on our hardware
          libnotify # Add `notify-send` command
        ];
      };
      linux = {
        environment.systemPackages = with pkgs; [
          # rclone # Don't need anymore as it was just used for Obsidian syncing
          gnat13 # Provides gcc, g++, etc
          # libgcc # Unsure why this doesn't gives gcc, g++, etc as programs to use, but it don't
          gnumake
          just # Task runner, like `make`
          nurl # Generates nix fetcher urls
          dust # A better `du` command. Just prints out size of directories in the CWD
          ncdu # Similar to `dust`, but provides a UI to delete directories
          tldr
          zbar # Can scan QR & bar codes using this
          wine # For running Windows applications on Linux
          nix-prefetch-github

          # yarn

          # OpenJDK 21 (as of time of this comment):
          zulu
          jre8

          # Fly.io control:
          flyctl

          awscli2
          mprocs
          entr # Run some command when file(s) change
          showport # List processes listening on a port, with full executable + args

          # Editors that can be ssh'd into and used:
          vscode
        ];
      };

      # darwin = {
      #   environment.systemPackages = with pkgs; [
      #   ];
      # };
    }
  );
}
