# Idea backlog

Ideas collected while designing SummerAI. They are **not** commitments; the
last column says where each one stands relative to the
[v1 roadmap](roadmap.md) and the [long-term roadmap](roadmap-long-term.md).

| Idea | Details | Status |
|---|---|---|
| Two-stage generation | A slow first pass builds a highly specialised knowledge base, with fact and consistency checks; a lighter model then answers users on top of it, to reduce the memory needed at query time. | Research, long term |
| Specialised models | Fine-tuning for narrow domains; chaining several LLMs. | Long term |
| Dynamic context memory | Promote concepts to a stable context depending on how often they recur in prompts, generations and user answers on a given topic. | Research, long term |
| Benchmarks per speciality | Compare existing models per domain, for example with RAGAS. | Partly in v1 (evaluation harness, milestone M3) |
| Server and local editions | A server edition (VPS or on-premises) and a containerised local edition that uses the client's own GPU, both deployed through CI pipelines on push, similar to how n8n is distributed. | v1 provides GPU and CPU-only Compose profiles |
| Model choice by context | Pick the model according to context and available resources: cloud API, local GPUs, or a hybrid of both. | Cloud variant after v1; a development-time version is the [delegated worker loop](delegated-loop.md) |
| Several modes | AI assistant, RAG, automation (n8n), agent acting on the machine, project mode (orchestration of several AIs). | v1 covers assistant, RAG and agents with restricted tools; the rest is long term |
| Peer-to-peer GPU mesh | Pool GPU resources across machines. | Long term (Track C) |
| Workload questionnaire | Ask users about their expected workload to anticipate deployments. | Long term (Track D) |
| Rented GPUs | Use a GPU marketplace such as vast.ai for burst capacity. | Long term (Track C) |
