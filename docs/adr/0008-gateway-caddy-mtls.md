# 8. Caddy with mutual TLS as the model gateway

- **Status:** Accepted
- **Date:** 2026-10-15
- **Supersedes:** [ADR 0003](0003-model-gateway.md)

## Context

The gateway is the only path to the model servers, so the design that is
**most secure by default** wins over convenience features.

- **LiteLLM** (ADR 0003) is open by default: without a master key, every
  request is accepted. Its admin UI and API docs are on by default. In 2026 it
  had a PyPI supply-chain compromise (versions 1.82.7 and 1.82.8,
  [vendor write-up](https://docs.litellm.ai/blog/security-update-march-2026))
  and several critical advisories, including an unauthenticated SQL injection
  in key verification and an authentication bypass to management routes
  ([LiteLLM advisories](https://github.com/BerriAI/litellm/security/advisories)).
- **`llama-server`** binds to `127.0.0.1` by default and supports API keys
  (`--api-key-file`). Health checks and the built-in web UI stay
  unauthenticated, and it has no client certificate support
  ([server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)).
- **Caddy** is a single static binary with automatic TLS, client certificate
  verification, body size limits, timeouts and forward authentication
  ([Caddy documentation](https://caddyserver.com/docs/)).
- v1 has few, known clients: Open WebUI, the orchestrator, the evaluation and
  benchmark scripts.

## Decision

- **Caddy is the only entry point to every model server.**
- **Machine clients authenticate with mutual TLS**, using certificates issued
  by a private certificate authority for this project, one per client. Each
  client also sends its own API key, and is only routed to the models it
  needs.
- **Humans only use Open WebUI**, behind the same proxy, with its own login.
- On `merlin`, each `llama-server` binds to `127.0.0.1` inside its container,
  with its own API key file. A Caddy instance in each container is the only
  listener on the network, accepts only the gateway's client certificate,
  and injects the key.
- `llama-server` runs with `--no-webui` and without slot inspection, property
  writes, tools, agent features or the RPC backend.
- Request body size, response timeouts and rate limits are set per client
  (OWASP LLM10, unbounded consumption).
- Host firewalls only accept gateway traffic on the model ports.

## Consequences

- No component in front of the models stores a database of keys or exposes an
  admin interface, so the attack surface stays small.
- Certificates must be issued, rotated and revoked. This is automated with
  Ansible and documented in the operations runbook.
- No built-in usage accounting or spend tracking: usage comes from the
  `llama-server` metrics and the gateway access logs, which is enough for a
  single-operator platform.
- Routing to a cloud model in the cloud variant is a new Caddy route with its
  own upstream credentials.
- If virtual keys or per-team budgets become a real need, LiteLLM can be
  reconsidered at a patched version, from a signed image, with its admin UI
  and docs disabled.

## Alternatives considered

- **LiteLLM**: rich features, but open by default and a large attack surface
  with a heavy 2026 advisory record.
- **`llama-server` API keys only**: simple, but keys travel in clear text
  without TLS, and health and UI endpoints stay open.
- **llama-swap**: useful to switch models later, but its API keys are off by
  default; if used, it sits behind Caddy.
- **Envoy AI Gateway**: designed for Kubernetes, more than v1 needs.
