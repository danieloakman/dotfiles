# Periodic vulnix system scan + optional human-signal feed poller.
# New findings go through cursor-agent triage before notify (when enabled).
# Notify prefers my.services.agent-telegram-bot send.
{ config, lib, pkgs, env, ... }:
let
  cfg = config.my.services.vuln-monitor;
  notifyCfg = cfg.notify.telegram;
  feedsCfg = cfg.feeds;
  triageCfg = cfg.triage;

  stateDir = "/var/lib/vuln-monitor";
  seenFile = "${stateDir}/seen.json";
  errorFlag = "${stateDir}/error-notified";
  feedsSeenFile = "${stateDir}/feeds-seen.json";
  feedsErrorFlag = "${stateDir}/feeds-error-notified";
  triageInboxDir = "${stateDir}/triage-inbox";

  cursorAgentOn = config.my.programs.cursor.agent.enable;
  hasGhToken = builtins.hasAttr "main_gh_token" (config.sops.secrets or { });

  cursorAgentExe = lib.getExe config.my.programs.cursor.agent.package;
  dotfilesDir = triageCfg.repo;
  worktreeDir = triageCfg.worktree;
  # Private to vuln-monitor (not ~/.claude/skills) so interactive agents stay clean.
  triageSkillHome = "${env.home}/.local/share/vuln-monitor/triage-skill";

  severityFloor =
    {
      critical = 9.0;
      high = 7.0;
      medium = 4.0;
      low = 0.1;
    }
    .${cfg.min-severity};

  whitelistToml =
    let
      cveLines = map (cve: ''  "${cve}",'') cfg.ignore-cves;
      starSection =
        if cfg.ignore-cves == [ ] then
          ""
        else
          ''
            ["*"]
            cve = [
            ${lib.concatStringsSep "\n" cveLines}
            ]
          '';
      pkgSections = map (pname: ''
        ["${pname}"]
      '') cfg.ignore-packages;
    in
    pkgs.writeText "vuln-monitor-whitelist.toml" (
      lib.concatStringsSep "\n" ([ starSection ] ++ pkgSections ++ [ cfg.extra-whitelist ])
    );

  agentTelegramBotExe = lib.getExe config.my.services.agent-telegram-bot.package;
  agentTelegramEnabled = config.my.services.agent-telegram-bot.enable;

  sourcesJsonFile = pkgs.writeText "vuln-monitor-sources.json" (
    builtins.toJSON (
      map (s: {
        inherit (s) name url;
      }) feedsCfg.sources
    )
  );

  keywordsJsonFile = pkgs.writeText "vuln-monitor-keywords.json" (builtins.toJSON feedsCfg.keywords);

  triageSkill = pkgs.runCommand "vuln-monitor-triage-skill" { } ''
    mkdir -p $out
    substitute ${./vuln-monitor-triage/reference.md} $out/reference.md \
      --subst-var-by repo ${lib.escapeShellArg dotfilesDir} \
      --subst-var-by worktree ${lib.escapeShellArg worktreeDir}
    cp ${./vuln-monitor-triage/SKILL.md} $out/SKILL.md
  '';

  # Prefer agent-telegram-bot bridge; optional legacy curl path via token-file.
  notifyScript =
    if notifyCfg.enable && agentTelegramEnabled then
      pkgs.writeShellScript "vuln-monitor-notify" ''
        set -euo pipefail
        msg=$1
        if [ "''${#msg}" -gt 3500 ]; then
          msg="''${msg:0:3400}

…truncated…"
        fi
        RUN_USER=${lib.escapeShellArg env.user}
        HOME_DIR=${lib.escapeShellArg env.home}
        if ! ${pkgs.util-linux}/bin/runuser -u "$RUN_USER" -- \
          env HOME="$HOME_DIR" USER="$RUN_USER" LOGNAME="$RUN_USER" \
          ${agentTelegramBotExe} send --role vuln-monitor "$msg"; then
          ${pkgs.util-linux}/bin/logger -t vuln-monitor "agent-telegram-bot send failed"
        fi
      ''
    else if notifyCfg.enable && notifyCfg.token-file != null then
      pkgs.writeShellScript "vuln-monitor-notify" ''
        set -euo pipefail
        msg=$1
        token_file=${lib.escapeShellArg notifyCfg.token-file}
        if [ ! -r "$token_file" ]; then
          ${pkgs.util-linux}/bin/logger -t vuln-monitor "notify skipped: token file not readable"
          exit 0
        fi
        token=$(${pkgs.coreutils}/bin/tr -d '\n' < "$token_file")
        if [ -z "$token" ] || [ "$token" = "REPLACE_ME" ]; then
          ${pkgs.util-linux}/bin/logger -t vuln-monitor "notify skipped: empty or REPLACE_ME token"
          exit 0
        fi
        if [ "''${#msg}" -gt 3500 ]; then
          msg="''${msg:0:3400}

…truncated…"
        fi
        for chat_id in $(${pkgs.jq}/bin/jq -r '.[]' <<<${lib.escapeShellArg (builtins.toJSON notifyCfg.chat-ids)}); do
          if ! ${pkgs.curl}/bin/curl -sf --max-time 20 \
            -X POST "https://api.telegram.org/bot''${token}/sendMessage" \
            --data-urlencode "chat_id=''${chat_id}" \
            --data-urlencode "text=''${msg}" \
            --data-urlencode "disable_web_page_preview=true" \
            -o /dev/null; then
            ${pkgs.util-linux}/bin/logger -t vuln-monitor "telegram send failed for chat_id=$chat_id"
          fi
        done
      ''
    else
      pkgs.writeShellScript "vuln-monitor-notify" ''
        ${pkgs.util-linux}/bin/logger -t vuln-monitor "notify disabled: $1"
      '';

  # Prepare isolated worktree, run cursor-agent as env.user, gate Telegram.
  # Args: <kind> <inbox.json> <raw_telegram_body>
  triageScript = pkgs.writeShellApplication {
    name = "vuln-monitor-triage";
    runtimeInputs = with pkgs; [
      coreutils
      git
      gh
      hostname
      jq
      util-linux
    ];
    text = ''
      set -euo pipefail

      log() { logger -t vuln-monitor-triage "$*"; }

      KIND=$1
      INBOX=$2
      RAW_BODY=$3

      HOST=$(hostname -s)
      REPO=${lib.escapeShellArg dotfilesDir}
      WORKTREE=${lib.escapeShellArg worktreeDir}
      SKILL_DIR=${lib.escapeShellArg triageSkillHome}
      CURSOR_AGENT=${lib.escapeShellArg cursorAgentExe}
      TIMEOUT_SEC=${lib.escapeShellArg (toString triageCfg.timeout-sec)}
      RUN_USER=${lib.escapeShellArg env.user}
      HOME_DIR=${lib.escapeShellArg env.home}
      GH_TOKEN_FILE=${lib.escapeShellArg (
        if hasGhToken then config.sops.secrets.main_gh_token.path else ""
      )}

      if [ ! -f "$INBOX" ]; then
        log "inbox missing: $INBOX"
        ${notifyScript} "⚠️ vuln-monitor-triage ($HOST): inbox missing; raw findings:

$RAW_BODY"
        exit 0
      fi

      item_count=$(jq '.items | length' "$INBOX")
      stamp=$(date -u +%Y%m%dT%H%M%SZ)
      short=$(jq -r '.items[0].key // "item"' "$INBOX" | tr -c 'a-zA-Z0-9._-' '_' | cut -c1-40)
      # Suggested name for easy_fix PRs only; triage itself stays on detached HEAD.
      branch="vuln-monitor/''${stamp}-''${short}"

      # All git ops as RUN_USER so the interactive repo's .git stays user-owned.
      as_user() {
        runuser -u "$RUN_USER" -- env HOME="$HOME_DIR" USER="$RUN_USER" LOGNAME="$RUN_USER" "$@"
      }

      # Drop leftover local vuln-monitor/* refs from older runs (remote PR branches stay).
      prune_stale_vuln_branches() {
        local b
        while IFS= read -r b; do
          [ -n "$b" ] || continue
          as_user git -C "$REPO" branch -D "$b" >/dev/null 2>&1 || true
        done < <(as_user git -C "$REPO" branch --list 'vuln-monitor/*' --format='%(refname:short)' 2>/dev/null || true)
      }

      prepare_worktree() {
        as_user mkdir -p "$(dirname "$WORKTREE")"
        if [ ! -d "$REPO/.git" ] && [ ! -f "$REPO/.git" ]; then
          log "repo missing or not a git checkout: $REPO"
          return 1
        fi
        as_user git -C "$REPO" worktree prune >/dev/null 2>&1 || true
        if [ -d "$WORKTREE" ]; then
          if ! as_user git -C "$WORKTREE" fetch origin main >/dev/null 2>&1; then
            log "git fetch failed in worktree"
            return 1
          fi
          # Detached at origin/main — no named branch unless the agent creates one for a PR.
          if ! as_user git -C "$WORKTREE" checkout --detach origin/main >/dev/null 2>&1 \
            || ! as_user git -C "$WORKTREE" reset --hard origin/main >/dev/null 2>&1 \
            || ! as_user git -C "$WORKTREE" clean -fd >/dev/null 2>&1; then
            log "git reset failed; recreating worktree"
            as_user git -C "$REPO" worktree remove --force "$WORKTREE" >/dev/null 2>&1 \
              || as_user rm -rf "$WORKTREE"
          fi
        fi
        if [ ! -d "$WORKTREE" ]; then
          if ! as_user git -C "$REPO" fetch origin main >/dev/null 2>&1; then
            log "git fetch failed in repo"
            return 1
          fi
          if ! as_user git -C "$REPO" worktree add --detach "$WORKTREE" origin/main >/dev/null 2>&1; then
            log "git worktree add failed"
            return 1
          fi
        fi
        prune_stale_vuln_branches
        return 0
      }

      if ! prepare_worktree; then
        log "worktree prepare failed; notifying raw findings"
        ${notifyScript} "⚠️ vuln-monitor ($HOST): triage worktree failed ($item_count item(s))

$RAW_BODY"
        exit 0
      fi

      out=$(mktemp)
      err=$(mktemp)
      trap 'rm -f "$out" "$err"' EXIT

      gh_token=""
      if [ -n "$GH_TOKEN_FILE" ] && [ -r "$GH_TOKEN_FILE" ]; then
        gh_token=$(tr -d '\n' < "$GH_TOKEN_FILE")
      fi

      # Inbox lives under StateDirectory (root); make it readable to the agent user.
      chmod a+rX "$INBOX" "$(dirname "$INBOX")" 2>/dev/null || true

      # Run agent as the interactive user so CURSOR_API_KEY wrapper, gh, and git creds work.
      set +e
      timeout --signal=KILL "$TIMEOUT_SEC" \
        runuser -u "$RUN_USER" -- \
        env HOME="$HOME_DIR" USER="$RUN_USER" LOGNAME="$RUN_USER" \
          VULN_INBOX="$INBOX" VULN_KIND="$KIND" VULN_HOST="$HOST" \
          VULN_WORKTREE="$WORKTREE" VULN_REPO="$REPO" VULN_BRANCH="$branch" \
          VULN_SKILL="$SKILL_DIR" \
          GH_TOKEN="$gh_token" GH_HOST=github.com \
        "$CURSOR_AGENT" -p --force --trust --workspace "$WORKTREE" \
          "Read \$VULN_SKILL/SKILL.md and follow that skill exactly (not a global ~/.claude skill). Inbox: $INBOX. Kind: $KIND. Host: $HOST. Worktree at $WORKTREE is detached on origin/main; create branch \$VULN_BRANCH only for easy_fix PRs. Never modify $REPO." \
        >"$out" 2>"$err"
      agent_rc=$?
      set -e

      if [ "$agent_rc" -ne 0 ]; then
        err_head=$(head -c 800 "$err" || true)
        log "cursor-agent failed rc=$agent_rc: $err_head"
        ${notifyScript} "⚠️ vuln-monitor ($HOST): triage failed (rc=$agent_rc); $item_count raw item(s)

$RAW_BODY"
        exit 0
      fi

      # Last line that looks like a JSON object (skill requires final-line JSON).
      verdict_json=$(${pkgs.gnugrep}/bin/grep -E '^[[:space:]]*\{' "$out" | tail -n1 || true)

      if [ -z "$verdict_json" ] || ! jq -e '.verdict' >/dev/null 2>&1 <<<"$verdict_json"; then
        log "failed to parse verdict JSON from agent stdout"
        ${notifyScript} "⚠️ vuln-monitor ($HOST): triage produced no verdict; $item_count raw item(s)

$RAW_BODY"
        exit 0
      fi

      verdict=$(jq -r '.verdict' <<<"$verdict_json")
      summary=$(jq -r '.summary // empty' <<<"$verdict_json")
      pr_url=$(jq -r '.pr_url // empty' <<<"$verdict_json")
      log "verdict=$verdict pr_url=''${pr_url:-none} summary=$(printf '%s' "$summary" | head -c 200)"

      case "$verdict" in
        not_affected)
          log "suppressing Telegram: $summary"
          ;;
        easy_fix)
          if [ -z "$pr_url" ] || [ "$pr_url" = "null" ]; then
            ${notifyScript} "🔐 vuln-monitor ($HOST): easy_fix without pr_url — needs review

$summary

$RAW_BODY"
          else
            ${notifyScript} "🔧 vuln-monitor ($HOST): easy_fix PR opened

$summary

$pr_url"
          fi
          ;;
        needs_review)
          ${notifyScript} "🔐 vuln-monitor ($HOST): needs review

$summary

$RAW_BODY"
          ;;
        *)
          log "unknown verdict=$verdict"
          ${notifyScript} "⚠️ vuln-monitor ($HOST): unknown verdict '$verdict'

$summary

$RAW_BODY"
          ;;
      esac
    '';
  };

  scanScript = pkgs.writeShellApplication {
    name = "vuln-monitor-scan";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      hostname
      jq
      util-linux
      vulnix
    ];
    text = ''
      set -euo pipefail

      log() { logger -t vuln-monitor "$*"; }

      STATE_DIR=${lib.escapeShellArg stateDir}
      SEEN_FILE=${lib.escapeShellArg seenFile}
      ERROR_FLAG=${lib.escapeShellArg errorFlag}
      INBOX_DIR=${lib.escapeShellArg triageInboxDir}
      MIN_CVSS=${lib.escapeShellArg (toString severityFloor)}
      WHITELIST=${lib.escapeShellArg whitelistToml}
      CACHE_DIR="''${STATE_DIR}/vulnix-cache"
      HOST=$(hostname -s)
      TRIAGE=${lib.boolToString triageCfg.enable}

      mkdir -p "$STATE_DIR" "$CACHE_DIR" "$INBOX_DIR"
      cd "$STATE_DIR"

      baseline=0
      if [ ! -f "$SEEN_FILE" ]; then
        baseline=1
      fi

      tmp=$(mktemp)
      trap 'rm -f "$tmp"' EXIT

      log "starting vulnix --system (min CVSS $MIN_CVSS)"
      if ! HOME="$STATE_DIR" vulnix --system --json \
        --cache-dir "$CACHE_DIR" \
        -w "$WHITELIST" \
        >"$tmp" 2>vulnix.err; then
        err=$(head -c 500 vulnix.err || true)
        log "vulnix failed: $err"
        if ${lib.boolToString cfg.notify-on-error}; then
          if [ ! -f "$ERROR_FLAG" ]; then
            ${notifyScript} "⚠️ vuln-monitor ($HOST): vulnix scan failed
$err"
            touch "$ERROR_FLAG"
          fi
        fi
        exit 0
      fi
      rm -f "$ERROR_FLAG"

      findings=$(jq -c --argjson min "$MIN_CVSS" '
        [
          .[] as $pkg
          | ($pkg.affected_by // [])[] as $cve
          | ($pkg.cvssv3_basescore[$cve] // 0) as $score
          | select(($score | tonumber) >= $min)
          | {
              key: ($pkg.pname + ":" + $cve),
              pname: $pkg.pname,
              name: $pkg.name,
              cve: $cve,
              score: $score
            }
        ] | unique_by(.key) | sort_by(-.score, .key)
      ' "$tmp")

      total=$(jq 'length' <<<"$findings")
      if [ "$baseline" -eq 1 ]; then
        jq -c '[.[].key] | unique | sort' <<<"$findings" >"$SEEN_FILE.tmp"
        mv "$SEEN_FILE.tmp" "$SEEN_FILE"
        log "baselined $total finding(s); no notify on first run"
        exit 0
      fi

      seen=$(cat "$SEEN_FILE")
      new=$(jq -c --argjson seen "$seen" '
        [ .[] | select(.key as $k | ($seen | index($k) | not)) ]
      ' <<<"$findings")

      new_count=$(jq 'length' <<<"$new")
      log "findings at/above floor: $total; new: $new_count"

      if [ "$new_count" -gt 0 ]; then
        body=$(jq -r '
          .[:15][]
          | "• \(.score) \(.cve) — \(.name)\n  https://nvd.nist.gov/vuln/detail/\(.cve)"
        ' <<<"$new")
        extra=""
        if [ "$new_count" -gt 15 ]; then
          extra=$(printf '\n…and %s more' "$((new_count - 15))")
        fi
        raw="🔐 vuln-monitor ($HOST): $new_count new ≥$MIN_CVSS finding(s)

$body$extra"

        if [ "$TRIAGE" = "true" ]; then
          inbox="$INBOX_DIR/vulnix-$(date -u +%Y%m%dT%H%M%SZ).json"
          jq -c --arg host "$HOST" '{kind:"vulnix",host:$host,items:.}' <<<"$new" >"$inbox"
          ${lib.getExe triageScript} vulnix "$inbox" "$raw"
        else
          ${notifyScript} "$raw"
          log "notified $new_count new finding(s)"
        fi
      fi

      jq -c --argjson seen "$seen" '
        (($seen + [.[].key]) | unique | sort)
      ' <<<"$findings" >"$SEEN_FILE.tmp"
      mv "$SEEN_FILE.tmp" "$SEEN_FILE"
    '';
  };

  feedsPy = pkgs.writeText "vuln-monitor-feeds.py" ''
    import json, sys, urllib.request, xml.etree.ElementTree as ET

    sources_path, keywords_path, seen_path = sys.argv[1:4]
    with open(sources_path) as f:
        sources = json.load(f)
    with open(keywords_path) as f:
        keywords = [k.lower() for k in json.load(f)]
    with open(seen_path) as f:
        seen = set(json.load(f))

    def text_of(el):
        if el is None:
            return ""
        return "".join(el.itertext()).strip()

    def local(tag):
        return tag.rsplit("}", 1)[-1]

    hits = []
    errors = []
    for src in sources:
        name, url = src["name"], src["url"]
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "vuln-monitor-feeds/1.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read()
            root = ET.fromstring(raw)
        except Exception as e:
            errors.append(f"{name}: {e}")
            continue

        entries = []
        for item in root.iter():
            if local(item.tag) != "item":
                continue
            title = link = summary = guid = ""
            for child in list(item):
                t = local(child.tag)
                if t == "title":
                    title = text_of(child)
                elif t == "link":
                    link = text_of(child) or child.attrib.get("href", "")
                elif t in ("description", "summary"):
                    summary = text_of(child)
                elif t == "guid":
                    guid = text_of(child)
            entries.append((title, link, summary, guid or link or title))
        if not entries:
            for item in root.iter():
                if local(item.tag) != "entry":
                    continue
                title = link = summary = guid = ""
                for child in list(item):
                    t = local(child.tag)
                    if t == "title":
                        title = text_of(child)
                    elif t == "link":
                        link = child.attrib.get("href", "") or text_of(child)
                    elif t in ("summary", "content"):
                        summary = text_of(child)
                    elif t == "id":
                        guid = text_of(child)
                entries.append((title, link, summary, guid or link or title))

        for title, link, summary, guid in entries[:40]:
            blob = f"{title}\n{summary}".lower()
            if keywords and not any(k in blob for k in keywords):
                continue
            key = f"{name}:{guid}"
            if key in seen:
                continue
            hits.append({
                "key": key,
                "source": name,
                "title": title[:200],
                "link": link,
            })

    print(json.dumps({"hits": hits, "errors": errors}))
  '';

  feedsScript = pkgs.writeShellApplication {
    name = "vuln-monitor-feeds";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      hostname
      jq
      util-linux
      python3
    ];
    text = ''
      set -euo pipefail

      log() { logger -t vuln-monitor-feeds "$*"; }

      STATE_DIR=${lib.escapeShellArg stateDir}
      SEEN_FILE=${lib.escapeShellArg feedsSeenFile}
      ERROR_FLAG=${lib.escapeShellArg feedsErrorFlag}
      INBOX_DIR=${lib.escapeShellArg triageInboxDir}
      HOST=$(hostname -s)
      TRIAGE=${lib.boolToString triageCfg.enable}

      mkdir -p "$STATE_DIR" "$INBOX_DIR"
      baseline=0
      seen_input=$SEEN_FILE
      if [ ! -f "$SEEN_FILE" ]; then
        baseline=1
        seen_input=$(mktemp)
        echo '[]' > "$seen_input"
        trap 'rm -f "$seen_input"' EXIT
      fi

      result=$(python3 ${feedsPy} ${sourcesJsonFile} ${keywordsJsonFile} "$seen_input")

      err_count=$(jq '.errors | length' <<<"$result")
      if [ "$err_count" -gt 0 ]; then
        errs=$(jq -r '.errors[]' <<<"$result")
        log "feed fetch errors: $errs"
        if ${lib.boolToString cfg.notify-on-error}; then
          if [ ! -f "$ERROR_FLAG" ]; then
            ${notifyScript} "⚠️ vuln-monitor-feeds ($HOST): feed errors
$errs"
            touch "$ERROR_FLAG"
          fi
        fi
      else
        rm -f "$ERROR_FLAG"
      fi

      new_count=$(jq '.hits | length' <<<"$result")
      log "new filtered feed hits: $new_count"

      if [ "$baseline" -eq 1 ]; then
        jq -c '[.hits[].key] | unique | sort' <<<"$result" >"$SEEN_FILE.tmp"
        mv "$SEEN_FILE.tmp" "$SEEN_FILE"
        log "baselined $new_count feed hit(s); no notify on first run"
        exit 0
      fi

      if [ "$new_count" -gt 0 ]; then
        body=$(jq -r '
          .hits[:10][]
          | "• [\(.source)] \(.title)\n  \(.link)"
        ' <<<"$result")
        extra=""
        if [ "$new_count" -gt 10 ]; then
          extra=$(printf '\n…and %s more' "$((new_count - 10))")
        fi
        raw="📰 vuln-monitor-feeds ($HOST): $new_count new item(s)

$body$extra"

        if [ "$TRIAGE" = "true" ]; then
          inbox="$INBOX_DIR/feeds-$(date -u +%Y%m%dT%H%M%SZ).json"
          jq -c --arg host "$HOST" '{kind:"feeds",host:$host,items:.hits}' <<<"$result" >"$inbox"
          ${lib.getExe triageScript} feeds "$inbox" "$raw"
        else
          ${notifyScript} "$raw"
        fi

        seen=$(cat "$SEEN_FILE")
        jq -c --argjson seen "$seen" '
          (($seen + [.hits[].key]) | unique | sort)
        ' <<<"$result" >"$SEEN_FILE.tmp"
        mv "$SEEN_FILE.tmp" "$SEEN_FILE"
      fi
    '';
  };
in
{
  options.my.services.vuln-monitor = {
    enable = lib.mkEnableOption ''
      Periodic vulnix --system scan with Telegram notify on new findings at/above
      the severity floor. Optional human-signal RSS/Atom feeds share the same
      notify path. Disabled by default.
    '';

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun *-*-* 04:30:00";
      description = ''
        systemd `OnCalendar` expression for the vulnix scan timer.
        Default: weekly Sunday 04:30 local time.
      '';
    };

    min-severity = lib.mkOption {
      type = lib.types.enum [
        "critical"
        "high"
        "medium"
        "low"
      ];
      default = "high";
      description = ''
        Minimum CVSSv3 severity to notify on.
        critical≥9.0, high≥7.0, medium≥4.0, low≥0.1.
        CVEs without a CVSSv3 score are treated as 0 and ignored.
      '';
    };

    ignore-cves = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "CVE-2023-12345" ];
      description = "CVE ids whitelisted for every package (vulnix `[\"*\"]` rule).";
    };

    ignore-packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "audiofile" ];
      description = "Package names (pname) whose advisories are fully whitelisted.";
    };

    extra-whitelist = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Raw TOML appended to the generated vulnix whitelist.";
    };

    notify-on-error = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        On scanner/network failure, send one Telegram notice and stay quiet until
        the next successful run (flag cleared on success).
      '';
    };

    triage = {
      enable = lib.mkEnableOption ''
        Run cursor-agent on new findings before Telegram. Suppresses not_affected
        alerts; opens a PR for easy_fix; otherwise sends a needs_review verdict.
      '';

      timeout-sec = lib.mkOption {
        type = lib.types.ints.positive;
        default = 600;
        description = "Hard kill timeout (seconds) for the cursor-agent triage process.";
      };

      repo = lib.mkOption {
        type = lib.types.str;
        default = "${env.home}/repos/personal/dotfiles";
        description = "Interactive git checkout (read-only reference; never modified by triage).";
      };

      worktree = lib.mkOption {
        type = lib.types.str;
        default = "${env.home}/.local/share/vuln-monitor/git-worktree";
        description = "Isolated git worktree used for easy_fix commits and PRs.";
      };
    };

    notify.telegram = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Send alerts via my.services.agent-telegram-bot (preferred) or a legacy
          curl path when `token-file` is set and the agent bridge is disabled.
        '';
      };

      chat-ids = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ ];
        example = [ 8348310754 ];
        description = ''
          Legacy curl notify only. Prefer agent-telegram-bot.chat-ids when the
          agent bridge is enabled.
        '';
      };

      token-file = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Legacy Bot API token file for curl notify when agent-telegram-bot is
          disabled. Unused when the agent bridge is enabled.
        '';
      };
    };

    feeds = {
      enable = lib.mkEnableOption ''
        Poll allowlisted RSS/Atom security feeds, keyword-filter, and notify on
        unseen items via the same Telegram path.
      '';

      interval = lib.mkOption {
        type = lib.types.str;
        default = "12h";
        description = "How often to poll feeds (`OnUnitActiveSec`).";
      };

      keywords = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "openssh"
          "openssl"
          "glibc"
          "musl"
          "linux"
          "sudo"
          "systemd"
          "pam"
          "nixos"
          "nixpkgs"
          "ssh"
          "curl"
          "nginx"
          "postgres"
          "docker"
          "password"
          "authentication"
          "remote code"
          "rce"
        ];
        description = "Case-insensitive substrings; an item must match at least one.";
      };

      sources = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Short label used in notifications and dedup keys.";
              };
              url = lib.mkOption {
                type = lib.types.str;
                description = "RSS or Atom feed URL.";
              };
            };
          }
        );
        default = [
          {
            name = "oss-security";
            url = "https://seclists.org/rss/oss-sec.rss";
          }
          {
            name = "nixos-security";
            url = "https://discourse.nixos.org/c/announcements/security/27.rss";
          }
          {
            name = "nixos-blog";
            url = "https://nixos.org/blog/announcements-rss.xml";
          }
        ];
        description = ''
          Allowlisted RSS/Atom sources. Failed fetches fail soft.
          OpenSSH/Alpine announce traffic usually shows up on oss-security;
          add extra URLs here if you want dedicated feeds.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion =
            !notifyCfg.enable
            || agentTelegramEnabled
            || (notifyCfg.token-file != null && notifyCfg.chat-ids != [ ]);
          message = ''
            my.services.vuln-monitor.notify.telegram.enable requires
            my.services.agent-telegram-bot.enable, or a legacy token-file + chat-ids.
          '';
        }
      ];

      systemd.services.vuln-monitor = {
        description = "vulnix system CVE scan + notify on new high/critical findings";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe scanScript;
          StateDirectory = "vuln-monitor";
          Nice = 10;
          IOSchedulingClass = "best-effort";
          IOSchedulingPriority = 6;
        };
      };

      systemd.timers.vuln-monitor = {
        description = "vulnix CVE scan timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.schedule;
          Persistent = true;
          RandomizedDelaySec = "30min";
          Unit = "vuln-monitor.service";
        };
      };
    }

    (lib.mkIf feedsCfg.enable {
      systemd.services.vuln-monitor-feeds = {
        description = "Security feed poller (keyword-filtered) for vuln-monitor";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe feedsScript;
          StateDirectory = "vuln-monitor";
          Nice = 10;
        };
      };

      systemd.timers.vuln-monitor-feeds = {
        description = "Security feed poller timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "20min";
          OnUnitActiveSec = feedsCfg.interval;
          Persistent = true;
          RandomizedDelaySec = "10min";
          Unit = "vuln-monitor-feeds.service";
        };
      };
    })

    (lib.mkIf triageCfg.enable {
      assertions = [
        {
          assertion = cursorAgentOn;
          message = "my.services.vuln-monitor.triage.enable requires my.programs.cursor.agent.enable.";
        }
      ];

      # Keep this skill out of ~/.claude/skills / Cursor slash stubs — timer-only.
      home-manager.users.${env.user}.home.file.".local/share/vuln-monitor/triage-skill".source =
        triageSkill;

      # Root oneshots call runuser; ensure worktree parent exists and is user-owned.
      systemd.tmpfiles.rules = [
        "d ${env.home}/.local/share/vuln-monitor 0755 ${env.user} users -"
      ];
    })
  ]);
}
