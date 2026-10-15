# 3. LiteLLM as the model gateway

- **Status:** Superseded by [ADR 0008](0008-gateway-caddy-mtls.md)
- **Date:** 2026-10-13

## Context

- Several inference backends will coexist: vLLM, llama.cpp, and later a
  managed cloud model service ([roadmap](../roadmap.md)).
- Model servers have no meaningful authentication of their own and should not
  be reachable by clients.
- Usage, latency and errors must be measured per client and per model.

## Decision

All model traffic goes through a **LiteLLM proxy** exposing the OpenAI API:

- one API key per client (Open WebUI, orchestrator, evaluation, benchmarks);
- routing by model name to the right backend, with fallback between profiles;
- usage and latency logged per key and per model.

Model servers only accept traffic from the gateway, enforced by the host
firewall.

## Consequences

- Clients depend on one stable API; backends can change freely.
- Adding the cloud variant after v1 is a configuration change in the gateway.
- One more network hop. Its overhead is measured in the benchmarks.
- The gateway stores keys and usage in a database; it gets its own database
  in the same PostgreSQL instance as retrieval.
- The gateway handles credentials and sees all prompts, so its container image
  is pinned by digest and upgrades are reviewed.

## Alternatives considered

- **No gateway**: each client talks to each backend; no central
  authentication or usage tracking.
- **Custom router**: full control, but rebuilds what LiteLLM already provides.
- **Kubernetes-native gateways**: relevant once the platform moves to
  Kubernetes (long-term roadmap), not for a Docker Compose v1.
