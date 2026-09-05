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
  local matches

  matches=$(git grep --untracked --exclude-standard -Il -E -e "$pattern" -- . \
    ':(exclude)scripts/check_secrets.sh' \
    ':(exclude)odoo_sdk/lib/src/utils/security_utils.dart' \
    ':(exclude)odoo_sdk/test/security_utils_test.dart' || true)

  if [[ -n "$matches" ]]; then
    echo "$description detected in:"
    printf '%s\n' "$matches"
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
scan_pattern \
  "URL containing inline credentials" \
  '(https?|wss?)://[^/@[:space:]]+:[^/@[:space:]]+@'

if [[ $status -ne 0 ]]; then
  echo "Secret scan failed. Remove the credential and rotate it if it was real."
  exit "$status"
fi

echo "Secret scan passed."
