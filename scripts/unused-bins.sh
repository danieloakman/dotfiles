#!/usr/bin/env bash
# Rank profile packages by least-recent binary access (atime).
# Advisory only: relatime is coarse; unused pkgs share activate-time atimes until first use.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
days=0
limit=40
all=0
baseline=0

usage() {
  cat <<'EOF'
Usage: unused-bins.sh [--days N] [--limit N] [--all] [--baseline]

  Group profile binaries by store package, rank by oldest atime in the group.
  After a rebuild, unused packages usually share the activate/build atime.

  --days N    Only show packages whose newest bin atime is older than N days (default: 0 = off).
  --limit N   Max rows to print (default: 40).
  --all       Include packages not mentioned in modules/ or hosts/.
  --baseline  Include coreutils/util-linux/etc (noisy; usually not removable).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)
      days="${2:?}"
      shift 2
      ;;
    --limit)
      limit="${2:?}"
      shift 2
      ;;
    --all)
      all=1
      shift
      ;;
    --baseline)
      baseline=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

cutoff=0
if [[ "$days" -gt 0 ]]; then
  cutoff=$(($(date +%s) - days * 86400))
fi

is_baseline_pkg() {
  local pkg="$1"
  [[ -z "$pkg" ]] && return 1
  case "$pkg" in
    bash-* | busybox-* | coreutils-* | diffutils-* | findutils-* | gawk-* | \
      gnugrep-* | gnumake-* | gnused-* | gnutar-* | gzip-* | bzip2-* | xz-* | \
      util-linux-* | procps-* | iputils-* | inetutils-* | net-tools-* | \
      shadow-* | pam-* | acl-* | attr-* | ncurses-* | readline-* | \
      glibc-* | gcc-* | binutils-* | linux-pam-* | systemd-* | kmod-* | \
      dbus-* | coreutils-full-* | getent-* | locale-* | iproute2-* | \
      fontconfig-* | sudo-* | curl-* )
      return 0
      ;;
  esac
  return 1
}

pkg_base_name() {
  local pkg="$1"
  sed -E 's/-[0-9][0-9A-Za-z._+-]*$//' <<<"$pkg"
}

repo_hits() {
  local pkg="$1"
  local base hits

  base=$(pkg_base_name "$pkg")
  [[ ${#base} -ge 3 ]] || return 0

  # Prefer explicit pkgs.<name> references; fall back to whole-word only for longer names.
  hits=$(
    rg -l --glob '*.nix' -e "pkgs\\.${base}\\b" "$repo/modules" "$repo/hosts" 2>/dev/null \
      | head -3 \
      | sed "s|^$repo/||" \
      | paste -sd, - || true
  )
  if [[ -z "$hits" && ${#base} -ge 6 ]]; then
    hits=$(
      rg -l -w --glob '*.nix' -F "$base" "$repo/modules" "$repo/hosts" 2>/dev/null \
        | head -3 \
        | sed "s|^$repo/||" \
        | paste -sd, - || true
    )
  fi
  printf '%s' "$hits"
}

bin_dirs=(
  "${HOME}/.nix-profile/bin"
  "/etc/profiles/per-user/${USER}/bin"
  /run/current-system/sw/bin
)

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/by-name" "$tmpdir/by-pkg"

for dir in "${bin_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r -d '' path; do
    name=$(basename "$path")
    [[ -e "$tmpdir/by-name/$name" ]] && continue
    : >"$tmpdir/by-name/$name"
    atime=$(stat -c '%X' "$path" 2>/dev/null) || continue
    store=$(readlink -f "$path" 2>/dev/null || true)
    pkg=""
    if [[ "$store" =~ ^/nix/store/[^-]+-([^/]+)/ ]]; then
      pkg="${BASH_REMATCH[1]}"
    fi
    [[ -n "$pkg" ]] || pkg="unknown:$name"
    # Package names must be single path segments (no slashes).
    pkg="${pkg//\//_}"

    # Track newest atime (last real use) + a few example bin names per package.
    meta="$tmpdir/by-pkg/$pkg"
    if [[ ! -f "$meta" ]]; then
      printf '%s\t%s\n' "$atime" "$name" >"$meta"
    else
      last_atime=$(cut -f1 "$meta")
      bins=$(cut -f2 "$meta")
      if [[ "$atime" -gt "$last_atime" ]]; then
        last_atime=$atime
      fi
      case ",$bins," in
        *,"$name",*) ;;
        *)
          count=$(tr ',' '\n' <<<"$bins" | grep -c . || true)
          if [[ "$count" -lt 3 ]]; then
            bins="$bins,$name"
          fi
          ;;
      esac
      printf '%s\t%s\n' "$last_atime" "$bins" >"$meta"
    fi
  done < <(find "$dir" -maxdepth 1 \( -type f -o -type l \) -print0 2>/dev/null)
done

mapfile -t rows < <(
  for meta in "$tmpdir/by-pkg"/*; do
    [[ -f "$meta" ]] || continue
    pkg=$(basename "$meta")
    IFS=$'\t' read -r atime bins <"$meta"
    if [[ "$cutoff" -gt 0 && "$atime" -ge "$cutoff" ]]; then
      continue
    fi
    printf '%s\t%s\t%s\n' "$atime" "$pkg" "$bins"
  done | sort -n
)

if [[ ${#rows[@]} -eq 0 ]]; then
  if [[ "$days" -gt 0 ]]; then
    echo "No packages with atime older than ${days}d in profile bin dirs."
  else
    echo "No binaries found in profile bin dirs."
  fi
  exit 0
fi

printf '%-12s  %-36s  %-28s  %s\n' "LAST_ACCESS" "PKG" "EXAMPLE BINS" "REPO"
printf '%-12s  %-36s  %-28s  %s\n' "------------" "------------------------------------" "----------------------------" "----"

shown=0
for row in "${rows[@]}"; do
  IFS=$'\t' read -r atime pkg bins <<<"$row"
  when=$(date -d "@$atime" +%Y-%m-%d 2>/dev/null || date -r "$atime" +%Y-%m-%d)

  if [[ "$baseline" -eq 0 ]] && is_baseline_pkg "$pkg"; then
    continue
  fi

  hits=$(repo_hits "$pkg")
  if [[ -z "$hits" && "$all" -eq 0 ]]; then
    continue
  fi
  if [[ -z "$hits" ]]; then
    hits="(not in modules/hosts)"
  fi

  printf '%-12s  %-36s  %-28s  %s\n' "$when" "$pkg" "$bins" "$hits"
  shown=$((shown + 1))
  [[ "$shown" -ge "$limit" ]] && break
done

if [[ "$shown" -eq 0 ]]; then
  echo "No matching packages. Try: --all  or  --baseline"
  exit 0
fi

echo
if [[ "$days" -gt 0 ]]; then
  echo "Showing ${shown} package(s) last accessed more than ${days}d ago (limit ${limit})."
else
  echo "Showing ${shown} least-recently-accessed package(s) (limit ${limit})."
fi
echo "relatime is coarse; identical dates usually mean unused since last profile build."
echo "Cross-check before removing — helpers may be pulled in transitively."
