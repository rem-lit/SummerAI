# Long-term roadmap

This document keeps the original vision of SummerAI (first written in French
in July 2026) and the work that sits **after** the v1 public release. The v1
scope itself is in [`roadmap.md`](roadmap.md).

## Target vision

The end goal is a platform where the user talks to a **single orchestrator
agent**, which routes requests to specialised retrieval, reasoning, review and
model-serving services, and deploys model profiles according to load and to
the GPU resources available.

## Where the original phases went

| Original phase | Topic | Now |
|---|---|---|
| 0 | Architecture, roles, model profiles, success criteria | v1, milestone M0 |
| 1 | Docker Compose MVP | v1, milestones M1 and M2 |
| 2 | Reliable RAG | v1, milestones M2 and M3 |
| 3 | Hierarchical agent layer | v1, milestone M4 |
| 4 | Multi-profile serving | v1 keeps 2 to 3 profiles (M1); the rest is below |
| 5 | Observability and evaluation | v1, milestone M3; the rest is below |
| 6 | Kubernetes readiness | Track A |
| 7 | k3s deployment | Track B; a first k3s deployment with a simple Helm chart follows v1 |
| 8 | Remote GPU burst | Track C |
| 9 | Dynamic model deployment | Track D |
| 10 | Hardening and operations | Track E; access control (M2), tool isolation (M4), backups and segmentation (M5) moved into v1 |

## Deferred from the original phases 0 to 5

These items were part of the first plan but are out of the v1 scope:

- **Four serving profiles**: `vllm-chat-standard`, `vllm-reasoning-medium`,
  `vllm-review-fast` and `vllm-large-burst`, plus an optional dedicated
  embeddings service. v1 runs 2 to 3 profiles behind the gateway
  ([ADR 0002](adr/0002-inference-runtimes.md)).
- **Model registry**: available models with metadata per model (context
  length, VRAM, expected latency, cost), used by an internal router.
- **Prompt replay**: re-running recorded production prompts against a new
  model or prompt version.
- **Queue metrics** and **agent output quality scores** on dashboards.

## Track A: Kubernetes readiness

Goal: prepare the migration to Kubernetes without breaking anything. The real
benefit of Kubernetes for model serving appears with GPU scheduling,
autoscaling, multiple replicas, warm pools and advanced routing.

Technical preparation:

- containerise every component cleanly;
- externalise all configuration;
- make services stateless where possible;
- clearly separate persistent volumes;
- separate network dependencies and secrets.

Deliverables:

- base manifests or Helm charts;
- label and annotation conventions;
- a probe strategy (liveness, readiness, startup);
- a storage strategy for model weights and caches.

## Track B: k3s deployment

Goal: run the platform on k3s in the homelab, with GPU orchestration, cleaner
service discovery and model-serving classes.

Foundation:

- k3s (or kubeadm);
- NVIDIA GPU Operator, depending on the hardware;
- ingress;
- persistent object storage;
- persistent vector database;
- one model-serving deployment per profile;
- GPU metrics, and autoscaling on relevant metrics.

Expected outcome:

- several model-serving services coexist;
- the router picks the right profile;
- the platform restarts cleanly;
- caches and indexes persist.

## Track C: Remote GPU burst

Goal: add on-demand GPU capacity. The control plane stays the same, but remote
nodes or pools (for example rented GPUs) are activated when needed, without
relying on a proprietary LLM API.

To build:

- logic that tracks available capacity;
- trigger thresholds;
- an optional warm pool;
- download and caching of model weights;
- routing to a remote backend when a local profile lacks VRAM.

Points of attention:

- cold starts of large models;
- proximity between storage and compute;
- network security of remote endpoints.

## Track D: Dynamic model deployment

Goal: the orchestrator no longer only picks a model that is already running;
it can request the deployment of a heavy profile based on load, request type
and available GPUs.

Target mechanism:

1. the orchestrator classifies the request;
2. it looks for a profile that is already warm;
3. otherwise it triggers a deployment;
4. it waits for readiness;
5. it routes the request;
6. it scales down afterwards, according to a policy.

## Track E: Hardening and long-term operations

Security and backups start in v1 and are reinforced at every stage. This track
turns the project into a durable private AI platform: governance, secret
rotation at scale and model maintenance.

To cover:

- RBAC and network segmentation at platform scale;
- vector store and object storage backups, with retention policies;
- secret rotation;
- quotas;
- isolation of agent tools;
- a model update policy;
- operations documentation (runbooks).
