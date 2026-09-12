#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

status=0

forbidden_files=$(git ls-files | grep -E '(^|/)(\.env($|\.)|[^/]+\.(pem|p12|pfx|key)$|service-account[^/]*\.json$)' || true)
if [[ -n "$forbidden_files" ]]; then
  echo "Potential secret-bearing files are tracked:"
  printf '%s\n' "$forbidden_files"
  status=1
fi

scan_pattern() {
  local description=$1
  local pattern=$2
  # Optional third argument: a sub-pattern for matches that are documentation
  # rather than credentials, such as the RFC 2606 reserved domains.
  local documentary=${3:-}
  local matches

  matches=$(git grep --untracked --exclude-standard -I -n -E -e "$pattern" -- . \
    ':(exclude)scripts/check_secrets.sh' \
    ':(exclude)odoo_sdk/lib/src/utils/security_utils.dart' \
    ':(exclude)odoo_sdk/test/security_utils_test.dart' || true)

  # A line is cleared only when EVERY match on it is documentary. Counting per
  # line keeps a real credential visible even when it shares the line with an
  # example URL, which erasing the documentary text would have hidden.
  if [[ -n "$matches" && -n "$documentary" ]]; then
    local kept="" line total doc
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      total=$(printf '%s' "$line" | grep -oE "$pattern" | wc -l | tr -d ' ')
      doc=$(printf '%s' "$line" | grep -oE "$documentary" | wc -l | tr -d ' ')
      if (( total > doc )); then
        kept+="$line"$'\n'
      fi
    done <<< "$matches"
    matches="${kept%$'\n'}"
  fi

  if [[ -n "$matches" ]]; then
    echo "$description detected in:"
    printf '%s\n' "$matches" | cut -d: -f1 | sort -u
    status=1
  fi
}

scan_pattern \
  "Private key material" \
  '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
scan_pattern \
  "Credential-like token" \
  '(AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[0-9A-Za-z]{36}|github_pat_[0-9A-Za-z_]{70,}|xox[baprs]-[0-9A-Za-z-]{10,}|sk-[0-9A-Za-z_-]{20,})'
scan_pattern \
  "Hexadecimal credential assignment" \
  "(api[_-]?key|token|secret|password)[^=:]{0,80}[=:][[:space:]]*['\"][0-9A-Fa-f]{32,128}['\"]"
# Reserved documentation hosts (RFC 2606) and loopback carry no real secret:
# tests that assert such URLs are REJECTED must not fail this gate.
scan_pattern \
  "URL containing inline credentials" \
  '(https?|wss?)://[^/@[:space:]]+:[^/@[:space:]]+@' \
  '(https?|wss?)://[^/@[:space:]]+:[^/@[:space:]]+@(example\.(com|org|net)|localhost|127\.0\.0\.1|[^/@[:space:]]*\.(invalid|test|example|local))([^A-Za-z0-9.-]|$)'

if [[ $status -ne 0 ]]; then
  echo "Secret scan failed. Remove the credential and rotate it if it was real."
  exit "$status"
fi

echo "Secret scan passed."
