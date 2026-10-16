# 9. Delegated worker loop for development

- **Status:** Proposed
- **Date:** 2026-10-16

## Context

Remote models write heavy code and long documents better than the local models
available on the homelab, but their usage is metered. Local models are good
enough to plan, check consistency and review. Most of the metered usage goes
to work that is not production: exploring a repository, summarising results,
planning and discussing.

SummerAI is public and its product promise is that private documents never
leave the platform. Any use of a remote model during development must not
weaken that promise.

## Decision

- Development uses a **delegated worker loop**: the local side writes the task
  sheet and the context pack, a remote worker returns a patch only, and
  deterministic checks decide. Git is the shared state and workers are
  stateless. See [the description](../delegated-loop.md).
- **Backends sit behind one adapter** (headless CLI, OpenAI-compatible hosted
  API, local `llama-server`). A per-repository `.workers.yaml` maps task
  classes to chains of backends, from cheapest to most capable, with attempt
  and cost caps.
- **The loop is a development workflow, never part of the runtime path.** A
  repository's content goes to a remote worker only if that repository allows
  it; the default is no, and nothing from the retrieval corpus or from the
  fictional company's confidential runbooks is ever sent.
- **Worker output is untrusted.** Patches run in a throwaway container without
  secrets or network access. Context packs are scanned for secrets and limited
  in size. No patch is merged automatically.
- **Every attempt is metered** and every action journalled. Published figures
  come from the metering report script, with the commit, model and settings
  used.
- Model tiers are chosen by **measured cost per solved task**.

## Consequences

- Remote usage concentrates on code production, which is what it is best at.
- The orchestrator code, the adapters and the gate are new components to
  build and test; they are tracked in issues #3 to #7.
- Terms of use, rate limits and data retention of each remote backend must be
  checked before it is relied on, especially for automated use.
- Quality depends on the context pack. This is why a retrieval index over the
  repositories is part of the plan.
- The decision is reviewed on 2026-10-28 against the first measurements, and
  superseded if the loop does not pay for itself.
- Supervision (journal, channel between models, Telegram) and the control
  plane are expected to get their own records, ADR 0010 and ADR 0011, when
  they are built.
