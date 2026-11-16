# Periodic vulnix system scan + optional human-signal feed poller.
# Notifies on new high/critical findings via Telegram Bot API (reuses telegram_bot_token).
{ config, lib, pkgs, env, ... }:
let
  cfg = config.my.services.vuln-monitor;
  notifyCfg = cfg.notify.telegram;
  feedsCfg = cfg.feeds;

  stateDir = "/var/lib/vuln-monitor";
  seenFile = "${stateDir}/seen.json";
  errorFlag = "${stateDir}/error-notified";
  feedsSeenFile = "${stateDir}/feeds-seen.json";
  feedsErrorFlag = "${stateDir}/feeds-error-notified";

  severityFloor =
    {
      critical = 9.0;
      high = 7.0;
      medium = 4.0;
      low = 0.1;
    }
    .${cfg.min-severity};

  # vulnix TOML whitelist from package/CVE ignore lists.
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

  tokenPath =
    if notifyCfg.token-file != null then
      notifyCfg.token-file
    else
      config.sops.secrets.telegram_bot_token.path;

  chatIdsJson = builtins.toJSON notifyCfg.chat-ids;

  sourcesJsonFile = pkgs.writeText "vuln-monitor-sources.json" (
    builtins.toJSON (
      map (s: {
        inherit (s) name url;
      }) feedsCfg.sources
    )
  );

  keywordsJsonFile = pkgs.writeText "vuln-monitor-keywords.json" (builtins.toJSON feedsCfg.keywords);

  notifyScript =
    if notifyCfg.enable then
      pkgs.writeShellScript "vuln-monitor-notify" ''
        set -euo pipefail
        # Args: message text. Sends to every configured chat id. Soft-fails on HTTP errors.
        msg=$1
        token_file=${lib.escapeShellArg tokenPath}
        if [ ! -r "$token_file" ]; then
          ${pkgs.util-linux}/bin/logger -t vuln-monitor "notify skipped: token file not readable"
          exit 0
        fi
        token=$(${pkgs.coreutils}/bin/tr -d '\n' < "$token_file")
        if [ -z "$token" ]; then
          ${pkgs.util-linux}/bin/logger -t vuln-monitor "notify skipped: empty token"
          exit 0
        fi
        # Telegram limit is 4096; keep headroom.
        if [ "''${#msg}" -gt 3500 ]; then
          msg="''${msg:0:3400}

…truncated…"
        fi
        for chat_id in $(${pkgs.jq}/bin/jq -r '.[]' <<<${lib.escapeShellArg chatIdsJson}); do
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


  scanScript = pkgs.writeShellApplication {
    name = "vuln-monitor-scan";
    runtimeInputs = with pkgs; [
      coreutils
      curl
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
      MIN_CVSS=${lib.escapeShellArg (toString severityFloor)}
      WHITELIST=${lib.escapeShellArg whitelistToml}
      CACHE_DIR="''${STATE_DIR}/vulnix-cache"
      HOST=$(hostname -s)

      mkdir -p "$STATE_DIR" "$CACHE_DIR"
      cd "$STATE_DIR"

      # Absent seen file ⇒ first successful run baselines without notifying.
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

      # Flatten to unique pname:cve keys at/above floor.
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
      # First successful run: seed baseline without notifying (avoid historical flood).
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
        ${notifyScript} "🔐 vuln-monitor ($HOST): $new_count new ≥$MIN_CVSS finding(s)

$body$extra"
        log "notified $new_count new finding(s)"
      fi

      # Persist union of previous seen + current keys (never re-notify).
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
      HOST=$(hostname -s)

      mkdir -p "$STATE_DIR"
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

      # First run: record current matches as seen without notifying.
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
        ${notifyScript} "📰 vuln-monitor-feeds ($HOST): $new_count new item(s)

$body$extra"
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

    notify.telegram = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Send alerts via Telegram Bot API using telegram_bot_token.";
      };

      chat-ids = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ ];
        example = [ 8348310754 ];
        description = ''
          Telegram chat or user ids to receive alerts. Private-chat user ids work
          once that user has started the bot.
        '';
      };

      token-file = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        defaultText = lib.literalExpression "config.sops.secrets.telegram_bot_token.path";
        description = "Path to bot token file. Defaults to the sops telegram_bot_token secret.";
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

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = notifyCfg.enable -> notifyCfg.chat-ids != [ ];
        message = "my.services.vuln-monitor.notify.telegram.chat-ids must be non-empty when Telegram notify is enabled.";
      }
    ];

    # Reuse the same sops key as telegram-bot (owner/mode match that module).
    sops.secrets.telegram_bot_token = lib.mkIf notifyCfg.enable {
      owner = env.user;
      group = "secrets";
      mode = "0440";
    };

    systemd.services.vuln-monitor = {
      description = "vulnix system CVE scan + notify on new high/critical findings";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe scanScript;
        StateDirectory = "vuln-monitor";
        # Root can read sops token; scanning the system store needs broad read.
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

    systemd.services.vuln-monitor-feeds = lib.mkIf feedsCfg.enable {
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

    systemd.timers.vuln-monitor-feeds = lib.mkIf feedsCfg.enable {
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
  };
}
