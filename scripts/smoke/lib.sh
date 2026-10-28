# Helpers shared by the smoke tests. Source it after setting key_file.
# shellcheck shell=bash disable=SC2154  # key_file is set by the sourcing script

for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "missing dependency: $cmd" >&2; exit 2; }
done
[[ -r "$key_file" ]] || { echo "cannot read API key file: $key_file" >&2; exit 2; }

failures=0
check() { # check <name> <detail shown on failure> <command...>
  local name=$1 detail=$2
  shift 2
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $name"
  else
    echo "FAIL  $name${detail:+: $detail}"
    failures=$((failures + 1))
  fi
}

holds() { # holds <jq filter> <json>: succeeds if the filter is true
  jq -e "$1" <<<"$2"
}

# The key is passed as a header file so it never appears in the process list.
auth_curl() {
  curl -sS --max-time 600 -H @<(printf 'Authorization: Bearer %s\n' "$(<"$key_file")") "$@"
}

post() { # post <url> <json body>
  auth_curl -H 'Content-Type: application/json' -d "$2" "$1"
}

check_auth() { # check_auth <base url> <model alias>: key required, alias listed
  local code models
  code=$(curl -sS -o /dev/null -w '%{http_code}' "$1/v1/models")
  check "$2: unauthenticated request rejected" "HTTP $code" test "$code" = 401
  models=$(auth_curl "$1/v1/models")
  check "$2: model listed" "$(jq -c '[.data[]?.id]' <<<"$models")" \
    holds "[.data[].id] | index(\"$2\") != null" "$models"
}

finish() {
  echo
  if (( failures > 0 )); then
    echo "$failures check(s) failed"
    exit 1
  fi
  echo "all checks passed"
}
