# 6. llama.cpp server as the only inference runtime in v1

- **Status:** Accepted
- **Date:** 2026-10-15
- **Supersedes:** [ADR 0002](0002-inference-runtimes.md)

## Context

- `merlin` has two Ampere cards: an RTX 3090 (24 GB) and an RTX 3060 (8 GB).
- v1 serves one user and a few agents, not many concurrent users. Answer
  reliability matters more than model size; the target is at least 20 tokens
  per second when generating.
- The candidate main models are recent Qwen releases distributed as GGUF
  quantisations, for example
  [Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B) (dense, Apache 2.0)
  and [Qwen3.6-35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B) (mixture
  of experts, 3B active parameters, Apache 2.0).
- vLLM's GGUF support is described in its own documentation as "highly
  experimental and under-optimized" and now needs an out-of-tree plugin
  ([vLLM GGUF documentation](https://docs.vllm.ai/en/latest/features/quantization/gguf.html)).
- llama.cpp's `llama-server` serves GGUF natively, exposes the OpenAI API and
  an Anthropic-compatible Messages API
  ([announcement](https://huggingface.co/blog/ggml-org/anthropic-messages-api-in-llamacpp)),
  embeddings and reranking, and Prometheus metrics.

## Decision

- **`llama-server` runs every model in v1**, one card per role, no model split
  across the two cards:
  - RTX 3090: the main language model, one slot, quantised key-value cache
    (`q8_0`, never `q4_0`);
  - RTX 3060: the embedding model and the reranker, each in its own
    `llama-server` process, without key-value cache quantisation.
- The main model, its quantisation, context length and sampling settings are
  chosen with the evaluation harness, not up front. Starting values come from
  the model card.
- llama.cpp is built from a pinned release with a CUDA version known to work
  (CUDA 13.2 breaks some quantisation types,
  [llama.cpp issue 21255](https://github.com/ggml-org/llama.cpp/issues/21255)).
- Optional features (multi-token prediction, a reasoning budget, a second
  model profile through llama-swap) are enabled only if the evaluation harness
  shows no regression.
- **vLLM stays a benchmark baseline**, not a production runtime: the same
  model family in a vLLM-native quantisation, measured on the RTX 3090 under
  concurrent load.

## Consequences

- One slot on the main model means requests from the UI, the agents and the
  evaluation run one after the other. This is acceptable for v1 and is
  documented; concurrency becomes a reason to revisit vLLM.
- The context length on 24 GB is limited by the model weights plus the
  key-value cache. Generation speed is measured at realistic context sizes,
  not only with an empty context.
- The CPU quickstart uses the same runtime with a small model, so the
  configuration is the same everywhere.
- Never enabled: the RPC backend, which has an unpatched critical
  vulnerability, and the built-in tool or agent features of `llama-server`.
  Models are only downloaded from trusted publishers, since GGUF parsing has
  had memory-safety bugs
  ([llama.cpp security advisories](https://github.com/ggml-org/llama.cpp/security/advisories)).

## Alternatives considered

- **vLLM as the main runtime** (ADR 0002): better under concurrent load, but
  GGUF is experimental, and concurrency is not the v1 need.
- **Ollama**: convenient, but adds a layer over llama.cpp with less control
  over its settings and metrics.
- **Splitting one large model across both cards**: adds memory capacity, not
  speed, and removes the dedicated retrieval card.
