# Architecture

> **Status:** target design for v1. No component is deployed yet; each section
> says which [milestone](roadmap.md) delivers it.

## Goals

- Answer questions over a private document corpus with **citations**, using
  models that run on hardware the operator controls.
- Enforce **who can read what** inside retrieval, not only in the UI.
- Expose models through **one authenticated, OpenAI-compatible gateway**, so
  backends can change without touching clients.
- Make quality and performance **measurable**: evaluation, traces, metrics and
  benchmarks are part of the system, not an afterthought.

## Logical architecture

```mermaid
flowchart LR
    user([User]) -->|HTTPS| proxy[Reverse proxy<br/>TLS and authentication]
    proxy --> ui[Open WebUI]
    ui -->|OpenAI API and user identity| orch[Orchestrator API]
    orch --> retr[Retrieval<br/>ACL filter, hybrid search, rerank]
    retr --> db[(PostgreSQL<br/>pgvector and full-text)]
    orch --> agents[Planner, executor, reviewer]
    agents --> tools[Allow-listed tools]
    orch --> gw[LiteLLM gateway]
    agents --> gw
    gw --> vllm[vLLM on RTX 3090]
    gw --> cpp[llama.cpp on CPU]
    src[/Documents/] --> ingest[Ingestion worker<br/>parse, chunk, embed]
    ingest --> db
    ingest --> raw[(Raw document store)]
    orch -.->|traces| otel[OpenTelemetry collector]
    gw -.->|metrics| prom[Prometheus]
    otel -.-> grafana[Grafana]
    prom -.-> grafana
```

### Query path

1. The reverse proxy terminates TLS and authenticates the user.
2. Open WebUI sends the conversation to the orchestrator through the OpenAI
   API, together with the user identity.
3. The orchestrator asks the retrieval service for context. Retrieval applies
   the user's access rights **in the database query**, then runs vector and
   full-text search, fuses the results and reranks them.
4. The orchestrator generates the answer through the gateway, either directly
   or through the agent layer, and returns it with citations.
5. Each step emits a trace span; the gateway and model servers expose
   metrics.

### Ingestion path

1. A document is submitted with its access rights.
2. The worker stores the original, extracts text, chunks it with the
   configured strategy and computes embeddings.
3. Chunks, embeddings, metadata, version and access rights are written in one
   transaction. A new version of a document replaces the previous chunks.

## Components

| Component | Technology | Role | Milestone |
|---|---|---|---|
| Reverse proxy | To be chosen (Caddy or Traefik) | TLS, authentication, single entry point | M5 (basic auth from M1) |
| Chat UI | Open WebUI | User interface | M2 |
| Orchestrator API | Python, FastAPI | OpenAI-compatible endpoint, retrieval, generation, citations | M2 |
| Retrieval store | PostgreSQL with pgvector | Vectors, full-text index, documents, versions, ACLs | M2 ([ADR 0004](adr/0004-retrieval-store.md)) |
| Ingestion worker | Python | Parsing, chunking, embeddings, versioning | M2 |
| Model gateway | LiteLLM | Authentication, routing, usage tracking | M1 ([ADR 0003](adr/0003-model-gateway.md)) |
| GPU inference | vLLM | Main model on the RTX 3090, in a VM with the GPU passed through | M1 ([ADR 0002](adr/0002-inference-runtimes.md), [ADR 0005](adr/0005-gpu-passthrough-vm.md)) |
| CPU inference | llama.cpp server | Small model; quickstart without GPU | M1 ([ADR 0002](adr/0002-inference-runtimes.md)) |
| Embeddings and reranker | To be chosen by evaluation | Encode chunks and queries, rerank candidates | M2 |
| Agent layer | Python, typed JSON schemas | Planner, executor, reviewer, tool allow-list | M4 |
| Observability | OpenTelemetry, Prometheus, Grafana | Traces, metrics, dashboards, alerts | M3 |
| Evaluation | Python | Golden dataset, retrieval and generation metrics | M3 |

## Infrastructure

SummerAI runs in a homelab built like a small production network: segmented
VLANs, a firewall that routes and filters between them, and two Proxmox VE
hypervisors.

### Hardware

| Host | Role | CPU | RAM | GPU | Storage |
|---|---|---|---|---|---|
| `merlin` | GPU hypervisor (tower PC) | AMD Ryzen 7 2700, 8 cores | 16 GB | NVIDIA RTX 3090, 24 GB | Over 2 TB (NVMe, SSD, HDD) |
| `kaamelott` | Main hypervisor (Dell PowerEdge R730) | Intel Xeon E5-2680 v4 | 96 GB | None | 2.4 TB, hardware RAID 5 |
| `lancelot` | Firewall, inter-VLAN routing, DHCP, internal DNS (Fortinet FortiGate 40F) | — | — | — | — |
| `bohort` | Switch (Cisco CBS250, 16 × 1 GbE and 2 × SFP) | — | — | — | — |

Both hypervisors run Proxmox VE. The R730 also has out-of-band management
(iDRAC).

Hosts are named after characters of the French TV series *Kaamelott*.

### Network

```mermaid
flowchart TB
    internet((Internet)) --- isp[ISP router]
    isp ---|WAN, no management| fw[Firewall · FortiGate 40F]
    fw ---|802.1Q trunk| sw[Switch · Cisco CBS250]
    sw --- mgmt[VLAN 10 · Management]
    sw --- srv[VLAN 20 · Servers]
    sw --- iot[VLAN 30 · IoT]
    mgmt --- hv[Hypervisor management<br/>admin workstation]
    srv --- vms[SummerAI virtual machines]
```

| Zone | Purpose |
|---|---|
| VLAN 10, Management | Hypervisor and network device management, admin workstation |
| VLAN 20, Servers | Virtual machines and services, including SummerAI |
| VLAN 30, IoT | Connected devices, isolated from the rest |
| Unused native VLAN | Native VLAN of every trunk and unused port; carries no traffic |
| Recovery network | Untagged, out-of-band access to the firewall only |

Principles already in place:

- Traffic between VLANs is **denied by default**; each flow needs an explicit,
  logged firewall rule.
- Management is only reachable from the management VLAN, never from the WAN.
- Only encrypted management protocols (SSH, HTTPS); Telnet and HTTP are off.
- Unused switch ports are disabled and parked in the unused VLAN.
- Hypervisors accept SSH keys only; the web UI requires two-factor
  authentication.
- Network device configurations are backed up daily and versioned.
- Nothing is exposed to the internet. Remote access will go through a
  WireGuard VPN.

### Proposed placement

| Virtual machine | Host | Runs |
|---|---|---|
| Inference | `merlin` | vLLM and any other GPU container, with the RTX 3090 passed through ([ADR 0005](adr/0005-gpu-passthrough-vm.md)) |
| Platform | `kaamelott` | Reverse proxy, Open WebUI, gateway, orchestrator, retrieval, PostgreSQL, ingestion, llama.cpp |
| Observability | `kaamelott` | Prometheus, Grafana, log storage |

`merlin` only has 16 GB of RAM, and a VM with a passed-through GPU keeps all
its memory locked. Everything that does not need the GPU therefore runs on
`kaamelott`, which has 96 GB.

All three sit in VLAN 20. Traffic between them stays inside the VLAN and does
not cross the firewall, so each VM also runs a host firewall that only accepts
the flows it needs (for example, only the platform VM may reach the vLLM
port).

Flows to add to the firewall flow matrix:

| From | To | Port | Purpose |
|---|---|---|---|
| Management VLAN | Platform VM | 443/tcp | UI and API |
| Management VLAN | SummerAI VMs | 22/tcp | Administration, Ansible |
| SummerAI VMs | Internet | 443/tcp | Container images, packages, model downloads |

## Open questions

- **GPU host memory**: 16 GB limits the inference VM to quantised models;
  an upgrade to 32 GB or more is recommended
  ([ADR 0005](adr/0005-gpu-passthrough-vm.md)).
- **Embeddings and reranker**: on the R730's CPU or on the GPU next to vLLM,
  decided by benchmark.
- **Raw document store**: an S3-compatible service or a plain volume. The
  distribution model of MinIO's community edition changed in 2025 and needs
  checking; Garage and SeaweedFS are alternatives.
- **Time synchronisation**: NTP is not configured on every device yet; it is
  needed to correlate traces and logs.
