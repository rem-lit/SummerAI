# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- English README with project goals, current status and target architecture.
- v1 roadmap ([`docs/roadmap.md`](docs/roadmap.md)) and architecture document
  ([`docs/architecture.md`](docs/architecture.md)).
- Use case: a private assistant for Essential Eight compliance and IT
  operations, with roles, data, success criteria and golden dataset plan
  ([`docs/use-case.md`](docs/use-case.md)).
- Architecture decision records ([`docs/adr/`](docs/adr/)): `llama-server` as
  the only runtime in v1 (ADR 0006), one LXC container per GPU (ADR 0007),
  Caddy with mutual TLS as the gateway (ADR 0008), PostgreSQL with pgvector
  (ADR 0004). ADRs 0002, 0003 and 0005 are kept as superseded.
- Apache 2.0 licence, security policy, contribution guide and pull request
  template.
- CI workflow (Markdown lint, link check, secret scan over the full history),
  pre-commit hooks and Dependabot updates for GitHub Actions.

- Description of the delegated worker loop used to build the project
  ([`docs/delegated-loop.md`](docs/delegated-loop.md)), a proposed ADR 0009,
  and a parallel track in the roadmap.
- GPU host runbook ([`docs/runbooks/gpu-host.md`](docs/runbooks/gpu-host.md)):
  pinned kernel, NVIDIA driver with DKMS, one unprivileged container for the
  RTX 3090, llama.cpp built from a pinned release, the main model served by
  `llama-server` on loopback with an API key.
- Host and container configuration files in [`deploy/merlin/`](deploy/merlin/):
  driver blacklist, persistence and device node units, sandboxed
  `llama-server` unit.
- Smoke test for a `llama-server` instance
  ([`scripts/smoke/llm.sh`](scripts/smoke/llm.sh)): authentication, model
  alias, chat with separated reasoning, tool call.

### Changed

- The original French roadmap is now an English long-term roadmap
  ([`docs/roadmap-long-term.md`](docs/roadmap-long-term.md)); phases 0 to 5 are
  re-planned in the v1 roadmap.
- `IDEAS.md` moved to [`docs/ideas.md`](docs/ideas.md) and translated.

### Fixed

- Duplicated table header in the roadmap's pull request sequence.

### Removed

- Empty `docker-compose.yml` and placeholder `.env.example`. Both come back
  with the first deployable services.
