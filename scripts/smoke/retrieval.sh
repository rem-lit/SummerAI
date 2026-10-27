#!/usr/bin/env bash
# Smoke test for the retrieval models: authentication, model aliases,
# embeddings (shape, norm, similarity) and reranking.
#
# Usage: scripts/smoke/retrieval.sh
# Environment:
#   EMBED_BASE_URL          default http://127.0.0.1:9932
#   EMBED_MODEL             default qwen3-embedding-0.6b
#   EMBED_DIM               default 1024
#   RERANK_BASE_URL         default http://127.0.0.1:9933
#   RERANK_MODEL            default qwen3-reranker-0.6b
#   RETRIEVAL_API_KEY_FILE  default /etc/llama/api-key
# Requires curl and jq. Exits non-zero if any check fails.
set -euo pipefail

embed_url="${EMBED_BASE_URL:-http://127.0.0.1:9932}"
embed_model="${EMBED_MODEL:-qwen3-embedding-0.6b}"
embed_dim="${EMBED_DIM:-1024}"
rerank_url="${RERANK_BASE_URL:-http://127.0.0.1:9933}"
rerank_model="${RERANK_MODEL:-qwen3-reranker-0.6b}"
key_file="${RETRIEVAL_API_KEY_FILE:-/etc/llama/api-key}"
# shellcheck source=scripts/smoke/lib.sh
source "$(dirname "$0")/lib.sh"

# Qwen3-Embedding expects an instruction before queries, not before documents.
query="Instruct: Given a question, retrieve passages that answer it
Query: Comment protéger les sauvegardes contre un rançongiciel ?"
related="Les sauvegardes doivent être chiffrées, testées régulièrement et au moins une copie doit être conservée hors ligne."
unrelated="La tarte Tatin se prépare avec des pommes caramélisées au beurre et au sucre."

# 1. Embeddings: one normalised vector per input, related text closer.
check_auth "$embed_url" "$embed_model"
resp=$(post "$embed_url/v1/embeddings" "$(jq -n --arg m "$embed_model" \
  --arg q "$query" --arg r "$related" --arg u "$unrelated" \
  '{model: $m, input: [$q, $r, $u]}')")
check "$embed_model: three vectors of $embed_dim dimensions" \
  "$(jq -c '[.data[]?.embedding | length] // .error' <<<"$resp")" \
  holds "[.data[].embedding | length] == [$embed_dim, $embed_dim, $embed_dim]" "$resp"
check "$embed_model: vectors normalised" "" \
  holds '[.data[].embedding | map(. * .) | add | sqrt | . - 1 | fabs < 0.001] | all' "$resp"
# Vectors are normalised, so the dot product is the cosine similarity.
# shellcheck disable=SC2016  # jq variables, not shell ones
sims=$(jq -c 'def dot(a; b): [a, b] | transpose | map(.[0] * .[1]) | add;
              [.data | sort_by(.index) | .[].embedding] as [$q, $r, $u]
              | {related: dot($q; $r), unrelated: dot($q; $u)}' <<<"$resp" 2>/dev/null || echo null)
check "$embed_model: query closer to the related passage" "$sims" \
  holds '.related > .unrelated' "$sims"

# 2. Reranking: the passage that answers the question comes first.
check_auth "$rerank_url" "$rerank_model"
resp=$(post "$rerank_url/v1/rerank" "$(jq -n --arg m "$rerank_model" --arg r "$related" \
  --arg u "$unrelated" '{
  model: $m, query: "Comment protéger les sauvegardes contre un rançongiciel ?",
  documents: [$u, $r, "Le guide d'\''hygiène de l'\''ANSSI recommande de mettre à jour les logiciels."]
}')")
check "$rerank_model: one score per document" "$(jq -c '.results // .error' <<<"$resp")" \
  holds '.results | length == 3' "$resp"
check "$rerank_model: answering passage ranked first" "$(jq -c '.results' <<<"$resp")" \
  holds '.results | max_by(.relevance_score) | .index == 1' "$resp"

finish
