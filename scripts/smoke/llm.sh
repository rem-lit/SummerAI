#!/usr/bin/env bash
# Smoke test for a llama-server instance: authentication, model alias,
# chat with separated reasoning, and one tool call.
#
# Usage: scripts/smoke/llm.sh
# Environment:
#   LLM_BASE_URL      default http://127.0.0.1:9931
#   LLM_API_KEY_FILE  default /etc/llama/api-key
#   LLM_MODEL         default qwen3.8-27b
#   LLM_REASONING     1 if the model must return reasoning_content (default 1)
# Requires curl and jq. Exits non-zero if any check fails.
set -euo pipefail

base_url="${LLM_BASE_URL:-http://127.0.0.1:9931}"
key_file="${LLM_API_KEY_FILE:-/etc/llama/api-key}"
model="${LLM_MODEL:-qwen3.8-27b}"
reasoning="${LLM_REASONING:-1}"

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

chat() { # chat <json body>
  auth_curl -H 'Content-Type: application/json' -d "$1" "$base_url/v1/chat/completions"
}

# 1. Unauthenticated requests are rejected.
code=$(curl -sS -o /dev/null -w '%{http_code}' "$base_url/v1/models")
check "unauthenticated request rejected" "HTTP $code" test "$code" = 401

# 2. The model is listed under its alias.
models=$(auth_curl "$base_url/v1/models")
check "model listed as $model" "$(jq -c '[.data[]?.id]' <<<"$models")" \
  holds "[.data[].id] | index(\"$model\") != null" "$models"

# 3. Chat: normal stop, clean content, reasoning kept apart.
resp=$(chat "$(jq -n --arg m "$model" '{
  model: $m, max_tokens: 4096,
  messages: [{role: "user", content: "In one sentence, what is the Essential Eight?"}]
}')")
check "chat finishes with stop" "$(jq -c '.choices[0].finish_reason // .error' <<<"$resp")" \
  holds '.choices[0].finish_reason == "stop"' "$resp"
check "chat content present, without reasoning tags" "" \
  holds '(.choices[0].message.content // "") | length > 0 and (contains("<think>") | not)' "$resp"
if [[ "$reasoning" == 1 ]]; then
  check "reasoning returned in reasoning_content" "" \
    holds '(.choices[0].message.reasoning_content // "") | length > 0' "$resp"
fi

# 4. Tool call: the model calls the tool with valid JSON arguments.
resp=$(chat "$(jq -n --arg m "$model" '{
  model: $m, max_tokens: 4096,
  messages: [{role: "user", content: "What is the weather in Perth right now? Use the tool."}],
  tools: [{type: "function", function: {
    name: "get_weather", description: "Get the current weather for a city",
    parameters: {type: "object", required: ["city"], properties: {
      city: {type: "string"},
      unit: {type: "string", enum: ["celsius", "fahrenheit"]}}}}}]
}')")
check "tool call finishes with tool_calls" "$(jq -c '.choices[0].finish_reason // .error' <<<"$resp")" \
  holds '.choices[0].finish_reason == "tool_calls"' "$resp"
check "tool called with valid arguments" "$(jq -c '.choices[0].message.tool_calls' <<<"$resp")" \
  holds '.choices[0].message.tool_calls[0].function
         | .name == "get_weather" and ((.arguments | fromjson | .city) | test("perth"; "i"))' "$resp"

echo
if (( failures > 0 )); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
