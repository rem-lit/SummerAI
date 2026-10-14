# 2. Inference runtimes: vLLM on GPU, llama.cpp on CPU

- **Status:** Accepted
- **Date:** 2026-10-13

## Context

- The homelab has one GPU: an NVIDIA RTX 3090 (24 GB, Ampere, compute
  capability 8.6), in a host with an 8-core AMD Ryzen 7 and 32 GB of RAM.
  The main hypervisor, a Dell R730 with a Xeon E5-2680 v4 and 96 GB of RAM,
  has no GPU.
- vLLM's prebuilt binaries require a GPU with compute capability 7.5 or
  higher ([vLLM installation requirements](https://github.com/vllm-project/vllm/blob/main/docs/getting_started/installation/gpu.cuda.inc.md)).
  Older cards, such as Pascal-generation data-centre GPUs, are not supported.
- vLLM gives high throughput on a supported GPU (continuous batching, paged
  attention) but loads one model per process and reserves most of the GPU
  memory up front.
- The v1 quickstart must work for someone who has no GPU at all.

## Decision

- **vLLM** serves the main model on the RTX 3090.
- **llama.cpp** (`llama-server`, GGUF models) serves a small model on CPU. It
  is the backend of the quickstart and a second, low-cost profile in the
  homelab. It is also the fallback for any GPU older than compute
  capability 7.5.
- v1 runs **two or three profiles**, not more: the main GPU model, the small
  CPU model, and, if evaluation shows it is worth it, a dedicated embeddings
  and reranking service.
- Both runtimes expose the OpenAI API and sit behind the gateway
  ([ADR 0003](0003-model-gateway.md)); clients never call them directly.

## Consequences

- With a single 24 GB card, only one vLLM model is loaded at a time. Changing
  the main model means restarting the vLLM service.
- The model must fit in 24 GB together with its KV cache. The model and
  quantisation are chosen with the benchmarks of milestone M3, not up front.
- Running embeddings and the reranker on the same GPU means lowering the share
  of memory reserved by vLLM. Whether they run there or on CPU is decided by
  measurement.
- Mixing runtimes is hidden from clients by the gateway, and is itself
  something to document and benchmark.

## Alternatives considered

- **vLLM only**: rules out the quickstart on machines without a supported GPU.
- **llama.cpp only**: simpler, but lower throughput under concurrent load on
  the RTX 3090.
- **Ollama**: convenient for a single user, but its scheduling and metrics are
  less suited to measuring throughput and latency under load.
- **Community vLLM builds for older GPUs**: unofficial, and would break the
  reproducibility goal.
