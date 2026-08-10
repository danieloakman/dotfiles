#!/usr/bin/env bash
# Non-interactive helpers for secrets/secrets.yaml.
# Always mutates via sops so the MAC stays valid (never hand-edit ciphertext).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../../../.." && pwd)
SECRETS_FILE="${REPO_ROOT}/secrets/secrets.yaml"
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-${HOME}/.config/sops/age/keys.txt}"
NIX_PKGS=(nixpkgs#sops nixpkgs#jq nixpkgs#yq-go)

usage() {
  cat <<'EOF'
Usage: sops-secrets.sh <command> [args]

Commands:
  verify              Decrypt; exit 0 only if MAC/keys are valid
  list                Print top-level secret key names
  get <key>           Print one secret value to stdout
  set <key> <value>   Set a string value (JSON-encodes safely)
  set-stdin <key>     Set value from raw stdin (multiline OK)
  set-file <key> <path>
                      Set value from raw file contents
  unset <key>         Remove a key (--idempotent)
  replace <plain.yaml>
                      Replace entire document with plaintext YAML via sops edit

Environment:
  SOPS_AGE_KEY_FILE   Override age key path (default: ~/.config/sops/age/keys.txt)
EOF
}

die() {
  echo "sops-secrets: $*" >&2
  exit 1
}

require_age_key() {
  [[ -f "${AGE_KEY_FILE}" ]] || die "age key not found at ${AGE_KEY_FILE}"
  export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"
}

require_secrets_file() {
  [[ -f "${SECRETS_FILE}" ]] || die "missing ${SECRETS_FILE}"
}

run_sops() {
  require_age_key
  require_secrets_file
  # shellcheck disable=SC2068
  nix shell ${NIX_PKGS[@]} -c sops "$@"
}

run_with_tools() {
  require_age_key
  require_secrets_file
  # shellcheck disable=SC2068
  nix shell ${NIX_PKGS[@]} -c "$@"
}

verify() {
  run_sops -d "${SECRETS_FILE}" >/dev/null
  echo "sops-secrets: OK (decrypt + MAC valid)"
}

list_keys() {
  run_with_tools bash -c "sops -d \"${SECRETS_FILE}\" | yq 'keys | .[]'"
}

get_key() {
  local key=$1
  case "${key}" in
  *\"* | *\'* | *\[* | *\]* | *\$*)
    die "invalid key characters: ${key}"
    ;;
  esac
  run_with_tools bash -c "
    plain=\$(sops -d \"${SECRETS_FILE}\")
    printf '%s\n' \"\$plain\" | yq -e 'has(\"${key}\")' >/dev/null || {
      echo \"sops-secrets: missing key: ${key}\" >&2
      exit 1
    }
    printf '%s\n' \"\$plain\" | yq -r '.\"${key}\"'
  "
}

json_encode_string() {
  # Raw string on stdin -> JSON string on stdout
  nix shell nixpkgs#jq -c jq -Rs .
}

set_key_from_json_stdin() {
  local key=$1
  run_sops set --value-stdin "${SECRETS_FILE}" "[\"${key}\"]"
  verify
}

set_key() {
  local key=$1
  local value=$2
  printf '%s' "${value}" | json_encode_string | set_key_from_json_stdin "${key}"
}

set_key_stdin() {
  local key=$1
  json_encode_string | set_key_from_json_stdin "${key}"
}

set_key_file() {
  local key=$1
  local path=$2
  [[ -f "${path}" ]] || die "file not found: ${path}"
  json_encode_string <"${path}" | set_key_from_json_stdin "${key}"
}

unset_key() {
  local key=$1
  run_sops unset --idempotent "${SECRETS_FILE}" "[\"${key}\"]"
  verify
}

replace_document() {
  local plain=$1
  [[ -f "${plain}" ]] || die "plaintext file not found: ${plain}"

  local work editor plain_abs
  plain_abs=$(cd "$(dirname "${plain}")" && pwd)/$(basename "${plain}")
  work=$(mktemp -d)
  editor="${work}/editor.sh"
  # shellcheck disable=SC2064
  trap 'rm -rf "'"${work}"'"' EXIT

  # Normalize via yq so we fail fast on invalid YAML before invoking sops.
  run_with_tools yq -e '.' "${plain_abs}" >/dev/null

  cat >"${editor}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cp "${plain_abs}" "\$1"
EOF
  chmod +x "${editor}"

  SOPS_EDITOR="${editor}" run_sops edit "${SECRETS_FILE}"
  rm -rf "${work}"
  trap - EXIT
  verify
}

main() {
  local cmd=${1:-}
  [[ -n "${cmd}" ]] || { usage; exit 1; }
  shift || true

  case "${cmd}" in
  verify)
    verify
    ;;
  list)
    list_keys
    ;;
  get)
    [[ $# -eq 1 ]] || die "usage: get <key>"
    get_key "$1"
    ;;
  set)
    [[ $# -eq 2 ]] || die "usage: set <key> <value>"
    set_key "$1" "$2"
    ;;
  set-stdin)
    [[ $# -eq 1 ]] || die "usage: set-stdin <key>"
    set_key_stdin "$1"
    ;;
  set-file)
    [[ $# -eq 2 ]] || die "usage: set-file <key> <path>"
    set_key_file "$1" "$2"
    ;;
  unset)
    [[ $# -eq 1 ]] || die "usage: unset <key>"
    unset_key "$1"
    ;;
  replace)
    [[ $# -eq 1 ]] || die "usage: replace <plain.yaml>"
    replace_document "$1"
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    die "unknown command: ${cmd}"
    ;;
  esac
}

main "$@"
