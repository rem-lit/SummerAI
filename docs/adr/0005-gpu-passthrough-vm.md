# 5. Give the GPU to a virtual machine through PCIe passthrough

- **Status:** Proposed
- **Date:** 2026-10-13

## Context

- The GPU host (`merlin`) has an Intel Core i5-14400F, 32 GB of RAM and an
  NVIDIA RTX 3090 (24 GB), and runs Proxmox VE. The CPU has no integrated
  graphics, so the RTX 3090 is also the card the host boots on.
- Every GPU workload is a Docker container (vLLM, and possibly the embeddings
  and reranking models), deployed with Ansible and Docker Compose.
- Proxmox offers two ways to give a guest the GPU: PCIe passthrough to a
  virtual machine (VFIO), or sharing the host's NVIDIA driver with an LXC
  container.
- Day-to-day administration should not need root on the hypervisor.

## Comparison

| Criterion | VM with PCIe passthrough | LXC container sharing the host driver |
|---|---|---|
| Isolation | Separate guest kernel; the IOMMU isolates the card. A compromised inference stack stays inside the VM | Shares the host kernel, and exposes the host's NVIDIA kernel driver to the container |
| NVIDIA driver | Installed in the VM only; the host just binds the card to `vfio-pci` | Installed on the host, with exactly matching user-space libraries in the container |
| Updates | Driver and kernel updates happen inside the VM, without touching the host | Every host kernel or driver update needs root on the host, and the container libraries must follow |
| Docker and NVIDIA Container Toolkit | Standard setup, identical to a cloud GPU instance | Docker inside LXC needs nesting and workarounds for the GPU runtime |
| Memory | All VM memory is locked while the card is attached: no ballooning, no overcommit | Shared with the host; nothing is reserved |
| GPU sharing | The card belongs to one VM; the host and other guests cannot use it | Several containers can use the card at the same time |
| Performance | Close to native | Native |
| Backups | Disk backups work; live migration and memory snapshots do not | Simple container backups |
| Portability | Same layout as a cloud GPU VM, so the Ansible roles carry over to the cloud variant | Specific to Proxmox |

## Decision

Pass the RTX 3090 through to a single **inference VM**, which runs every GPU
container.

The host needs a one-time setup with root: IOMMU enabled, the card bound to
`vfio-pci`, and a Proxmox PCI resource mapping for it. After that, the VM is
managed with an account limited to the SummerAI VMs and allowed to use that
mapping.

## Consequences

- The VM's memory is locked for as long as it runs. With 32 GB on the host,
  the VM can get about 24 GB, enough to load a model that fills the card,
  but little is left for other guests on `merlin`.
- No other guest on `merlin` can use the GPU. Anything that needs it runs
  inside the inference VM.
- The RTX 3090 is the host's only display adapter. The host must release it
  at boot (no framebuffer on the card) and is then managed over the network
  only; local console access goes through a temporary display card.
- The CPU mixes performance and efficient cores; pinning the VM's vCPUs to
  the performance cores is worth benchmarking.
- CPU-only services (database, gateway, CPU inference, observability) run on
  the main hypervisor, which has far more memory.
