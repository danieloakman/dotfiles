# Recap skill: repo-wide “where did I leave off?” plus a gather helper with
# pinned CLI deps (jq, sqlite, git, gh, …).
{ pkgs, config, lib, env, ... }:
let
  enable = config.my.programs.agents.enable;

  jq = lib.getExe pkgs.jq;
  sqlite3 = lib.getExe' pkgs.sqlite "sqlite3";
  git = lib.getExe pkgs.git;
  gh = lib.getExe pkgs.gh;
  # coreutils/findutils/gnused/gnugrep/gawk via PATH for find/date/md5sum/…
  pathBin = lib.makeBinPath [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnused
    pkgs.gnugrep
    pkgs.gawk
  ];

  recapGather = pkgs.writeShellScriptBin "recap-gather" ''
    set -euo pipefail
    export PATH=${pathBin}''${PATH:+:$PATH}

    JQ=${jq}
    SQLITE3=${sqlite3}
    GIT=${git}
    GH=${gh}

    REPO="''${REPO:-''${1:-.}}"
    if "$GIT" -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      REPO_ABS=$("$GIT" -C "$REPO" rev-parse --show-toplevel)
    else
      REPO_ABS=$(cd "$REPO" && pwd -P)
    fi

    slug=$(echo "$REPO_ABS" | sed 's|^/||' | tr '/' '-')
    claude_key="-$slug"
    chats_hash=$(printf '%s' "$REPO_ABS" | md5sum | awk '{print $1}')

    CURSOR_PROJECTS="''${HOME}/.cursor/projects/''${slug}"
    CURSOR_TRANSCRIPTS="''${CURSOR_PROJECTS}/agent-transcripts"
    CURSOR_CHATS="''${HOME}/.cursor/chats/''${chats_hash}"
    CLAUDE_DIR="''${HOME}/.claude/projects/''${claude_key}"
    OPENCODE_DBS=(
      "''${HOME}/.local/share/opencode/opencode.db"
      "''${HOME}/.local/share/opencode/opencode-stable.db"
    )

    epoch_to_human() {
      local sec="$1"
      if [[ -z "$sec" || "$sec" == "null" || "$sec" == "0" ]]; then
        echo "?"
        return
      fi
      date -d "@''${sec}" '+%Y-%m-%d %H:%M' 2>/dev/null \
        || date -r "$sec" '+%Y-%m-%d %H:%M' 2>/dev/null \
        || echo "$sec"
    }

    ms_to_human() {
      local ms="$1"
      if [[ -z "$ms" || "$ms" == "null" ]]; then
        echo "?"
        return
      fi
      local sec="$ms"
      if (( ms > 100000000000 )); then
        sec=$((ms / 1000))
      fi
      epoch_to_human "$sec"
    }

    file_mtime_human() {
      local f="$1"
      local sec
      sec=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
      epoch_to_human "$sec"
    }

    truncate_one_line() {
      local s="$1"
      local max="''${2:-120}"
      s=$(printf '%s' "$s" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if (( ''${#s} > max )); then
        printf '%s…' "''${s:0:max}"
      else
        printf '%s' "$s"
      fi
    }

    extract_user_query_hint() {
      local file="$1"
      [[ -f "$file" ]] || return 0
      "$JQ" -r '
        select(.role == "user" or .type == "user") |
        (.message.content // .message // empty) |
        if type == "array" then
          [.[] | select(.type == "text") | .text] | join(" ")
        elif type == "object" then
          (.content // .text // empty |
            if type == "array" then [.[] | select(.type == "text" or type == "string") | (if type == "object" then .text else . end)] | join(" ")
            else .
            end)
        else .
        end
      ' "$file" 2>/dev/null | head -n 3 | while IFS= read -r line; do
        if [[ "$line" == *"<user_query>"* ]]; then
          line=$(printf '%s' "$line" | sed -n 's/.*<user_query>[[:space:]]*//;s/[[:space:]]*<\/user_query>.*//p')
        fi
        line=$(printf '%s' "$line" | sed 's/<timestamp>[^<]*<\/timestamp>//g')
        if [[ -n "$line" && "$line" != "null" ]]; then
          truncate_one_line "$line" 140
          echo
          break
        fi
      done
    }

    echo "# Recap index"
    echo
    echo "- **Repo:** \`$REPO_ABS\`"
    echo "- **Generated:** $(date -Iseconds 2>/dev/null || date)"
    echo

    echo "## Git"
    echo
    if "$GIT" -C "$REPO_ABS" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      branch=$("$GIT" -C "$REPO_ABS" branch --show-current 2>/dev/null || echo "?")
      echo "- **Branch:** \`$branch\`"
      upstream=$("$GIT" -C "$REPO_ABS" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)
      if [[ -n "$upstream" ]]; then
        ahead_behind=$("$GIT" -C "$REPO_ABS" rev-list --left-right --count "''${upstream}...HEAD" 2>/dev/null || true)
        if [[ -n "$ahead_behind" ]]; then
          behind=''${ahead_behind%%$'\t'*}
          ahead=''${ahead_behind#*$'\t'}
          echo "- **Upstream:** \`$upstream\` (ahead $ahead, behind $behind)"
        else
          echo "- **Upstream:** \`$upstream\`"
        fi
      else
        echo "- **Upstream:** (none)"
      fi
      echo
      echo "### Status"
      echo '```'
      "$GIT" -C "$REPO_ABS" status -sb 2>/dev/null || true
      echo '```'
      echo
      echo "### Recent commits"
      echo '```'
      "$GIT" -C "$REPO_ABS" log -10 --oneline --decorate 2>/dev/null || true
      echo '```'
      echo
      echo "### Stashes (current branch prefix)"
      stash_out=$("$GIT" -C "$REPO_ABS" stash list 2>/dev/null | grep -E "^stash@\{[0-9]+\}: .*''${branch}:" || true)
      if [[ -n "$stash_out" ]]; then
        echo '```'
        printf '%s\n' "$stash_out"
        echo '```'
      else
        echo "_None matching \`''${branch}:\` (or no stashes)._"
      fi
      echo
    else
      echo "_Not a git repository._"
      echo
    fi

    echo "## GitHub"
    echo
    if "$GIT" -C "$REPO_ABS" remote get-url origin >/dev/null 2>&1; then
      if "$GH" -R "$("$GIT" -C "$REPO_ABS" remote get-url origin 2>/dev/null)" repo view >/dev/null 2>&1 \
        || (cd "$REPO_ABS" && "$GH" repo view >/dev/null 2>&1); then
        echo "### Open pull requests"
        echo '```'
        (cd "$REPO_ABS" && "$GH" pr list --state open --limit 10 2>/dev/null) || echo "(gh pr list failed)"
        echo '```'
        echo
        if [[ -n "''${branch:-}" && "$branch" != "?" && "$branch" != "main" && "$branch" != "master" ]]; then
          echo "### PR for current branch"
          echo '```'
          (cd "$REPO_ABS" && "$GH" pr view --json number,title,url,state,statusCheckRollup,mergeable 2>/dev/null \
            | "$JQ" -r '
                if .number then
                  "#\(.number) \(.title)\n\(.url)\nstate=\(.state) mergeable=\(.mergeable // "?")\nchecks: " +
                  ((.statusCheckRollup // []) | map("\(.name // .context // "?"):\(.state // .conclusion // "?")") | join(", "))
                else "none"
                end
              ') || echo "(no PR for branch or gh failed)"
          echo '```'
          echo
        fi
        echo "### Recently updated open issues"
        echo '```'
        (cd "$REPO_ABS" && "$GH" issue list --state open --limit 10 --json number,title,updatedAt,url 2>/dev/null \
          | "$JQ" -r '.[] | "#\(.number) \(.title) (\(.updatedAt)) \(.url)"') \
          || echo "(gh issue list failed)"
        echo '```'
        echo
      else
        echo "_gh cannot view this repo (auth or non-GitHub remote)._"
        echo
      fi
    else
      echo "_No origin remote._"
      echo
    fi

    echo "## Cursor agent sessions"
    echo
    if [[ -d "$CURSOR_TRANSCRIPTS" ]]; then
      mapfile -t cursor_files < <(
        find "$CURSOR_TRANSCRIPTS" -type f -name '*.jsonl' -printf '%T@\t%p\n' 2>/dev/null \
          | sort -rn | head -n 20 | cut -f2-
      )
      declare -A seen_uuid=()
      count=0
      for f in "''${cursor_files[@]:-}"; do
        [[ -f "$f" ]] || continue
        uuid=$(basename "$(dirname "$f")")
        [[ -z "''${seen_uuid[$uuid]:-}" ]] || continue
        seen_uuid[$uuid]=1
        title="(no title)"
        updated="?"
        meta="''${CURSOR_CHATS}/''${uuid}/meta.json"
        if [[ -f "$meta" ]]; then
          title=$("$JQ" -r '.title // "(no title)"' "$meta" 2>/dev/null || echo "(no title)")
          updated_ms=$("$JQ" -r '.updatedAtMs // empty' "$meta" 2>/dev/null || true)
          if [[ -n "$updated_ms" ]]; then
            updated=$(ms_to_human "$updated_ms")
          else
            updated=$(file_mtime_human "$f")
          fi
        else
          updated=$(file_mtime_human "$f")
        fi
        hint=$(extract_user_query_hint "$f" || true)
        echo "- **''${title}** — ''${updated}"
        echo "  - uuid: \`''${uuid}\`"
        echo "  - transcript: \`$f\`"
        if [[ -n "$hint" ]]; then
          echo "  - hint: $(truncate_one_line "$hint" 140)"
        fi
        if [[ -d "''${HOME}/.cursor/plans" ]]; then
          mapfile -t plans < <(find "''${HOME}/.cursor/plans" -maxdepth 1 -type f -name "*''${uuid:0:8}*" 2>/dev/null | head -n 3)
          for p in "''${plans[@]:-}"; do
            [[ -f "$p" ]] && echo "  - plan: \`$p\`"
          done
        fi
        count=$((count + 1))
        (( count >= 5 )) && break
      done
      if (( count == 0 )); then
        echo "_No agent transcripts found._"
      fi
    else
      echo "_No Cursor project dir: \`$CURSOR_PROJECTS\`_"
    fi
    echo

    echo "## Claude Code sessions"
    echo
    if [[ -d "$CLAUDE_DIR" ]]; then
      mapfile -t claude_files < <(
        find "$CLAUDE_DIR" -maxdepth 1 -type f -name '*.jsonl' -printf '%T@\t%p\n' 2>/dev/null \
          | sort -rn | head -n 5 | cut -f2-
      )
      if (( ''${#claude_files[@]} == 0 )); then
        echo "_No session jsonl in \`$CLAUDE_DIR\`_"
      else
        for f in "''${claude_files[@]}"; do
          sid=$(basename "$f" .jsonl)
          updated=$(file_mtime_human "$f")
          hint=$(extract_user_query_hint "$f" || true)
          echo "- **session** \`''${sid}\` — ''${updated}"
          echo "  - transcript: \`$f\`"
          if [[ -n "$hint" ]]; then
            echo "  - hint: $(truncate_one_line "$hint" 140)"
          fi
        done
      fi
      hist="''${HOME}/.claude/history.jsonl"
      if [[ -f "$hist" ]]; then
        hist_hits=$("$JQ" -c --arg p "$REPO_ABS" 'select(.project == $p)' "$hist" 2>/dev/null | tail -n 5 || true)
        if [[ -n "$hist_hits" ]]; then
          echo
          echo "### Recent history.jsonl entries"
          while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            disp=$(printf '%s' "$line" | "$JQ" -r '.display // empty' 2>/dev/null || true)
            ts=$(printf '%s' "$line" | "$JQ" -r '.timestamp // empty' 2>/dev/null || true)
            echo "- $(truncate_one_line "''${disp:-?}" 100) ($ts)"
          done <<<"$hist_hits"
        fi
      fi
    else
      echo "_No Claude project dir: \`$CLAUDE_DIR\`_"
    fi
    echo

    echo "## OpenCode sessions"
    echo
    seen_oc=0
    declare -A seen_ses=()
    if [[ "$REPO_ABS" == *"'"* ]]; then
      echo "_OpenCode skipped: repo path contains a single quote._"
      echo
    else
    for db in "''${OPENCODE_DBS[@]}"; do
      [[ -f "$db" ]] || continue
      rows=$("$SQLITE3" "$db" \
        "SELECT id || '|' || replace(title, '|', '/') || '|' || time_updated FROM session WHERE directory = '$REPO_ABS' ORDER BY time_updated DESC LIMIT 5;" \
        2>/dev/null || true)
      [[ -n "$rows" ]] || continue
      echo "### From \`$(basename "$db")\`"
      while IFS='|' read -r sid title ts; do
        [[ -z "$sid" ]] && continue
        [[ -z "''${seen_ses[$sid]:-}" ]] || continue
        seen_ses[$sid]=1
        echo "- **''${title}** — $(ms_to_human "$ts")"
        echo "  - id: \`''${sid}\`"
        if [[ "$sid" == *"'"* ]]; then
          continue
        fi
        part=$("$SQLITE3" "$db" \
          "SELECT data FROM part WHERE session_id = '$sid' ORDER BY time_updated DESC LIMIT 15;" \
          2>/dev/null || true)
        if [[ -n "$part" ]]; then
          hint=$(printf '%s\n' "$part" | while IFS= read -r pdata; do
            printf '%s' "$pdata" | "$JQ" -r 'select(.type == "text") | .text // empty' 2>/dev/null
          done | grep -v '^$' | head -n 1 || true)
          if [[ -n "$hint" ]]; then
            echo "  - hint: $(truncate_one_line "$hint" 140)"
          fi
        fi
        seen_oc=1
      done <<<"$rows"
      echo
    done
    if (( seen_oc == 0 )); then
      echo "_No OpenCode sessions for this directory._"
      echo
    fi
    fi

    echo "## Paths resolved"
    echo
    echo "- Cursor slug: \`$slug\`"
    echo "- Cursor chats hash: \`$chats_hash\`"
    echo "- Claude key: \`$claude_key\`"
    echo
    echo "_End of gather index (read-only)._"
  '';

  recapSkill = pkgs.runCommand "recap-skill" { } ''
    mkdir -p $out
    cp ${./recap/reference.md} $out/reference.md
    substitute ${./recap/SKILL.md} $out/SKILL.md \
      --subst-var-by recapGather ${lib.escapeShellArg (lib.getExe recapGather)}
  '';
in
{
  config = lib.mkIf enable {
    my.programs.agents.skill-dirs.recap = recapSkill;

    # Keep defaults (nodejs/gh) and append gather for sandboxed agent PATH.
    my.programs.agents.sandbox.extra-allowed-packages = lib.mkAfter [ recapGather ];

    home-manager.users.${env.user} = {
      home.packages = [ recapGather ];
    };
  };
}
