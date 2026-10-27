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

# shellcheck source=scripts/smoke/lib.sh
source "$(dirname "$0")/lib.sh"

chat() { # chat <json body>
  post "$base_url/v1/chat/completions" "$1"
}

# 1. Unauthenticated requests are rejected and the model is listed.
check_auth "$base_url" "$model"

# 2. Chat: normal stop, clean content, reasoning kept apart.
resp=$(chat "$(jq -n --arg m "$model" '{
  model: $m, max_tokens: 4096,
  messages: [{role: "user", content: "En une phrase, à quoi sert le guide d\u0027hygiène informatique de l\u0027ANSSI ?"}]
}')")
check "chat finishes with stop" "$(jq -c '.choices[0].finish_reason // .error' <<<"$resp")" \
  holds '.choices[0].finish_reason == "stop"' "$resp"
check "chat content present, without reasoning tags" "" \
  holds '(.choices[0].message.content // "") | length > 0 and (contains("<think>") | not)' "$resp"
if [[ "$reasoning" == 1 ]]; then
  check "reasoning returned in reasoning_content" "" \
    holds '(.choices[0].message.reasoning_content // "") | length > 0' "$resp"
fi

# 3. Tool call: the model calls the tool with valid JSON arguments.
resp=$(chat "$(jq -n --arg m "$model" '{
  model: $m, max_tokens: 4096,
  messages: [{role: "user", content: "Quel est le score CVSS de la CVE-2024-3094 ? Utilise l\u0027outil."}],
  tools: [{type: "function", function: {
    name: "get_cve", description: "Get the details of a CVE, including its CVSS score",
    parameters: {type: "object", required: ["cve_id"], properties: {
      cve_id: {type: "string", description: "Identifier such as CVE-2021-44228"}}}}}]
}')")
check "tool call finishes with tool_calls" "$(jq -c '.choices[0].finish_reason // .error' <<<"$resp")" \
  holds '.choices[0].finish_reason == "tool_calls"' "$resp"
check "tool called with valid arguments" "$(jq -c '.choices[0].message.tool_calls' <<<"$resp")" \
  holds '.choices[0].message.tool_calls[0].function
         | .name == "get_cve" and ((.arguments | fromjson | .cve_id) | test("^CVE-2024-3094$"; "i"))' "$resp"

finish
