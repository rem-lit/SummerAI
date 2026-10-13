# Roadmap to v1

v1 is the first public release: a self-hosted RAG assistant with citations,
per-user access control, a small agent layer, measured quality and
performance, and a documented, reproducible deployment.

Work after v1 is described in [`roadmap-long-term.md`](roadmap-long-term.md).

## Principles

- **Vertical slice first.** A thin end-to-end path (model, retrieval,
  evaluation) comes before any optimisation, so every later change is measured
  against a baseline.
- **Measured, not claimed.** Every score or benchmark in this repository comes
  from a script in this repository.
- **Security from the first milestone.** Authentication, access control and
  tool isolation are built in as each layer is added, not bolted on at the
  end.
- **Always presentable.** Each pull request keeps the README status accurate.

## Milestones

| Milestone | Scope | Status |
|---|---|---|
| M0 Foundation | Repository standards, roadmap, architecture, decision records, use case | In progress |
| M1 Model serving | Inference backends behind an authenticated OpenAI-compatible gateway | Not started |
| M2 Retrieval | Hybrid RAG with citations, per-user access control, asynchronous ingestion | Not started |
| M3 Measurement | Evaluation harness, observability, hardware benchmarks | Not started |
| M4 Agents | Planner, executor and reviewer with JSON contracts and restricted tools | Not started |
| M5 Security and operations | Hardening, security tests, infrastructure as code, backup and restore | Not started |
| M6 Release | v1.0.0 | Not started |

### M0 Foundation

- Repository standards: licence, security policy, contribution guide, CI with
  secret scanning.
- This roadmap, the [architecture](architecture.md) and the
  [decision records](adr/).
- Use case and corpus (`docs/use-case.md`): problem, users, data, success
  criteria.

**Done when** the use case is written and the architecture reflects it.

### M1 Model serving

- vLLM serving one instruction model on the RTX 3090
  ([ADR 0002](adr/0002-inference-runtimes.md)).
- llama.cpp serving a small GGUF model on CPU, for the quickstart and as a
  second profile.
- LiteLLM gateway in front of both, with one API key per client and no
  unauthenticated endpoint ([ADR 0003](adr/0003-model-gateway.md)).
- Docker Compose profiles: `gpu` for the homelab, `cpu` for anyone else.

**Done when** an OpenAI client can chat through the gateway with both
profiles, and a smoke test runs in CI against the CPU profile.

### M2 Retrieval

- Ingestion of the corpus with configurable chunking and embeddings.
- Hybrid search (vector and full-text, fused with reciprocal rank fusion),
  then a reranker ([ADR 0004](adr/0004-retrieval-store.md)).
- Answers cite their sources.
- An OpenAI-compatible endpoint, used by Open WebUI as its model.
- **Per-user access control** enforced inside the retrieval query, with the
  user identity propagated from the UI.
- Asynchronous ingestion worker, document versioning by content hash, and a
  re-indexing strategy.

**Done when** automated tests show that a user never retrieves a chunk from a
document they are not allowed to read, and every answer carries citations.

### M3 Measurement

- A golden dataset of at least 50 questions, written and checked by hand.
- `make eval`: retrieval metrics (recall@k, MRR, nDCG) run in CI; generation
  metrics (faithfulness, answer relevancy, citation accuracy) run on the
  homelab, with results committed alongside the commit, model and settings
  used.
- Per-request traces; metrics for latency, time to first token, tokens per
  second, error rate, GPU utilisation and memory; Grafana dashboards and basic
  alerts exported to `observability/`.
- Benchmarks in `benchmarks/`: throughput, time to first token, behaviour
  under load, VRAM, power draw, and cost per million tokens compared with a
  cloud API.

**Done when** the README shows real scores and benchmark numbers, each
reproducible with a documented command.

### M4 Agents

- An orchestrator that delegates to a planner, an executor and a reviewer.
- JSON contracts between agents, validated with typed schemas.
- An allow-list of tools per agent, with least privilege.
- An execution log per run.
- A comparison with plain RAG on the golden dataset, for quality and latency.

**Done when** the agent layer is kept only where it measurably improves
answers, and the trade-off is documented.

### M5 Security and operations

- Reverse proxy with TLS and authentication in front of every endpoint;
  secrets management; audit logs for access and tool calls.
- `docs/security.md`: threat model, controls in place, mapping to the
  OWASP Top 10 for LLM Applications and to the ASD Essential Eight where
  relevant.
- Test suites for prompt injection (direct, and indirect through poisoned
  documents) and for cross-user data leakage.
- Terraform for the virtual machines and Ansible for configuration and
  deployment, in `infra/`.
- Network documentation: zones, flow matrix and firewall rules (sanitised).
- Backup, and an automated restore into a fresh environment.

**Done when** the security tests run in CI with documented results, and a
restore reproduces the same retrieval scores as the original.

### M6 Release

- README with architecture diagram, screenshots or a demo recording, and the
  measured numbers.
- Quickstart tested from a fresh clone on a machine without a GPU.
- Tag `v1.0.0`.

## Pull request sequence

| # | Branch | Milestone | Scope |
|---|---|---|---|
| 1 | `chore/repo-foundation` | M0 | Licence, community files, CI, English documentation |
| 2 | `docs/use-case` | M0 | Use case and corpus |
| 3 | `feat/inference-gateway` | M1 | vLLM, llama.cpp, LiteLLM, Compose profiles, smoke test |
| 4 | `feat/rag-baseline` | M2 | Ingestion, hybrid search, reranker, citations, Open WebUI |
| 5 | `feat/eval-harness` | M3 | Golden dataset, `make eval`, first scores |
| 6 | `feat/access-control` | M2 | Document ACLs, identity propagation, leakage tests |
| 7 | `feat/async-ingestion` | M2 | Worker, versioning, re-indexing |
| 8 | `feat/observability` | M3 | Traces, metrics, dashboards, alerts |
| 9 | `bench/inference` | M3 | Hardware benchmarks and cost comparison |
| 10 | `feat/agent-orchestrator` | M4 | Agents, contracts, tool allow-list, comparison |
| 11 | `security/hardening-tests` | M5 | Proxy, auth, secrets, audit logs, security tests |
| 12 | `infra/iac-network` | M5 | Terraform, Ansible, network documentation |
| 13 | `ops/backup-restore` | M5 | Backup and automated restore test |
| 14 | `docs/v1-release` | M6 | Final README and release |

The evaluation harness (5) lands right after the baseline (4) so that every
later change is measured. Benchmarks (9) only depend on model serving (3) and
can be done in parallel.

## After v1

- **Cloud variant**: the same application against a managed model service,
  with `docs/local-vs-cloud.md` comparing cost, latency, data privacy,
  sovereignty and maintenance effort.
- **Kubernetes**: a k3s deployment with a simple Helm chart.

## Definition of done for v1

- Someone who has never seen the project can clone it, follow the quickstart
  and get a working RAG chat.
- The README contains an architecture diagram, screenshots and real numbers:
  RAG scores, latency and tokens per second.
- The golden dataset and the evaluation script run with one command, and in
  CI.
- Security tests (prompt injection, isolation between users) are documented
  with their results.
- Per-user access rights are enforced in retrieval.
- A backup and a restore have been tested.
- No secret in the git history, checked in CI.
