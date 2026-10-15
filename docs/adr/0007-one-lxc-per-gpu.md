# 7. One LXC container per GPU, sharing the host driver

- **Status:** Accepted
- **Date:** 2026-10-15
- **Supersedes:** [ADR 0005](0005-gpu-passthrough-vm.md)

## Context

- The GPU host (`merlin`) now has two cards: an NVIDIA RTX 3090 (24 GB) and an
  RTX 3060 (8 GB), both Ampere. It has an Intel Core i5-14400F, without
  integrated graphics, and 32 GB of RAM.
- Each card has one role: the 3090 serves the main language model, the 3060
  serves the embedding and reranking models ([ADR 0006](0006-llama-server-runtime.md)).
- The model servers are native `llama-server` binaries, not containers.
- The maintainer has root on the host, so host-level driver and kernel
  updates are not a blocker.

ADR 0005 chose PCIe passthrough to one VM. With two cards, that means two VMs,
each with its memory locked for as long as it runs: 32 GB is not enough for
both plus the host.

## Decision

- The NVIDIA driver is installed **on the host** from the official `.run`
  package, with DKMS and the Proxmox kernel headers. The same version is
  installed in each container with `--no-kernel-module`.
- **One LXC container per GPU.** Each container only sees the device nodes of
  its own card, declared with `devN:` entries rather than raw
  `cgroup2.devices.allow` rules, whose major numbers can change between boots.
- `llama-server` runs as a native binary under systemd inside each container.
  There is no Docker inside the containers.
- The host kernel is pinned to a version validated with both cards. A kernel
  or driver update is applied only after `dkms status` confirms the module
  built for the new kernel.
- The 3090's power limit is set at boot by a systemd `oneshot` unit, at a value
  chosen with the benchmarks.

## Consequences

- Memory is shared with the host instead of being locked per VM, so both
  roles fit in 32 GB.
- Isolation is weaker than with a VM: the containers share the host kernel,
  and the NVIDIA kernel driver is part of their attack surface. The
  containers are unprivileged, expose only their own card, and accept traffic
  only through the gateway.
- Driver updates touch the host and both containers at once, and must keep
  their versions identical. Ansible pins the version in one place.
- The deployment layout on `merlin` (systemd units) differs from the platform
  VM (Docker Compose). Ansible covers both.
- The layout is specific to Proxmox. The cloud variant will use a GPU VM
  instead; the `llama-server` configuration carries over unchanged.

## Alternatives considered

- **PCIe passthrough to one VM per card** (ADR 0005): stronger isolation, but
  two VMs with locked memory do not fit in 32 GB.
- **Both cards in one VM**: one VM with all GPU workloads, but most of the
  host's memory locked and a single point of failure for chat and retrieval.
- **Docker inside the containers**: possible with nesting, but adds a layer
  with known GPU runtime workarounds for no benefit with native binaries.
