# Runbook: GPU host and LLM container

How `merlin` and the LLM container are set up for
[M1](../roadmap.md#m1-model-serving), following
[ADR 0006](../adr/0006-llama-server-runtime.md) and
[ADR 0007](../adr/0007-one-lxc-per-gpu.md). Every step was run by hand and
checked before the next one; Ansible will replace this runbook in M5.

The configuration files referenced below are in
[`deploy/merlin/`](../../deploy/merlin/).

> **Status:** host and LLM container done. Still to do in M1: the RTX 3060
> container, the power limit and its benchmarks, and the Caddy gateway.

## Pinned versions

| Component | Version | Why |
|---|---|---|
| Proxmox VE | 9.2 | Current release |
| Host kernel | 6.17.13-21-pve, pinned | Kernel 7.0, the 9.2 default, has reported NVIDIA problems on RTX 30-series cards |
| NVIDIA driver | 595.104.02, production branch, open kernel modules, DKMS | Current production branch; open modules are recommended for Ampere |
| CUDA toolkit (container) | 13.1 | CUDA 13.2 breaks some quantisation types ([llama.cpp #21255](https://github.com/ggml-org/llama.cpp/issues/21255)), fixed in 13.3, which the 595 driver does not support |
| llama.cpp | v0.7.0, commit `620d2225cc436ab0b001e3200e590e3b286ef9ab` | First stable release; passed the chat and tool-call smoke test |
| Main model | `unsloth/Qwen3.8-27B-GGUF`, file `Qwen3.8-27B-UD-Q4_K_XL.gguf`, revision `4ca720788d1e01f1bff70c033e0d0028fd02e502` | Apache 2.0 |

## 1. Host: kernel

```bash
apt install proxmox-kernel-6.17 proxmox-headers-6.17
proxmox-boot-tool kernel pin 6.17.13-21-pve
```

Only the 6.17 headers are installed, so DKMS builds the driver for that
kernel only. Before any kernel or driver update, `dkms status` must show the
module built for the new kernel.

## 2. Host: keep the open drivers away

Copy [`blacklist-nvidia-open-drivers.conf`](../../deploy/merlin/host/blacklist-nvidia-open-drivers.conf)
to `/etc/modprobe.d/`, run `update-initramfs -u -k all` and reboot.

Check: `uname -r` shows the pinned kernel, `lsmod` shows no `nouveau` or
`nova` module, and Secure Boot is disabled (`mokutil --sb-state`); otherwise
the unsigned DKMS module would not load.

## 3. Host: NVIDIA driver

```bash
apt install build-essential dkms pkg-config
V=595.104.02
B=https://download.nvidia.com/XFree86/Linux-x86_64/$V
wget "$B/NVIDIA-Linux-x86_64-$V.run" "$B/NVIDIA-Linux-x86_64-$V.run.sha256sum"
sha256sum -c "NVIDIA-Linux-x86_64-$V.run.sha256sum"
sh "NVIDIA-Linux-x86_64-$V.run" --dkms
```

Answers: MIT/GPL kernel modules, DKMS yes, 32-bit libraries no,
`nvidia-xconfig` no. The checksum comes from the same server: it detects a
corrupted download, not a tampered one.

Check before rebooting: `dkms status` shows the module as `installed` for the
pinned kernel, `modinfo -F license nvidia` shows `Dual MIT/GPL`, and
`nvidia-smi` lists both cards.

## 4. Host: persistence and device nodes

Copy [`nvidia.conf`](../../deploy/merlin/host/nvidia.conf) to
`/etc/modules-load.d/`, and the two units
[`nvidia-persistenced.service`](../../deploy/merlin/host/nvidia-persistenced.service)
and [`nvidia-uvm-devices.service`](../../deploy/merlin/host/nvidia-uvm-devices.service)
to `/etc/systemd/system/`, then:

```bash
systemctl daemon-reload
systemctl enable --now nvidia-persistenced nvidia-uvm-devices
```

The persistence daemon keeps the driver loaded, so device nodes and power
limits survive idle periods. `/dev/nvidia-uvm*` is not created at boot, and
CUDA in the containers needs it.

Check after a reboot: both services are `active`, persistence mode is
`Enabled` on both cards, and `/dev/nvidia0`, `/dev/nvidia1`, `/dev/nvidiactl`,
`/dev/nvidia-uvm` and `/dev/nvidia-uvm-tools` exist. Device modes are not
widened on the host; each container sets its own group and mode.

## 5. LLM container

An unprivileged Debian 13 container that only sees the RTX 3090
(`/dev/nvidia0` on this host, the card at the lowest PCI address).

```bash
pct create <id> <storage>:vztmpl/debian-13-standard_<version>_amd64.tar.zst \
  --hostname elias --unprivileged 1 --features nesting=1 \
  --cores 6 --memory 16384 --swap 0 \
  --rootfs <fast-storage>:80 \
  --net0 name=eth0,bridge=vmbr0,tag=20,ip=dhcp,firewall=1 \
  --onboot 1
pct set <id> \
  --dev0 /dev/nvidia0,gid=2000,mode=0660 \
  --dev1 /dev/nvidiactl,gid=2000,mode=0660 \
  --dev2 /dev/nvidia-uvm,gid=2000,mode=0660 \
  --dev3 /dev/nvidia-uvm-tools,gid=2000,mode=0660
```

`devN:` entries are used rather than `cgroup2.devices.allow` rules, because
the major number of `nvidia-uvm` is assigned at boot. The other card,
`nvidia-modeset` and `nvidia-caps` are not passed.

Inside the container, the same driver without its kernel module:

```bash
groupadd -g 2000 gpu
sh NVIDIA-Linux-x86_64-595.104.02.run --no-kernel-module
```

Check: `nvidia-smi` in the container lists the RTX 3090 only. Its
`Persistence-M` column reads `Off` inside the container; the host value is
the one that counts.

The container needs to resolve `deb.debian.org`,
`developer.download.nvidia.com`, `github.com`, `huggingface.co` and the
Hugging Face download host `cas-bridge.xethub.hf.co`.

## 6. llama.cpp

CUDA toolkit only, from NVIDIA's Debian 13 repository. Never install the
`cuda` or `cuda-drivers` packages: they would install a second driver.

```bash
apt install build-essential cmake git wget ca-certificates libssl-dev pkg-config
wget https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb && apt update
apt install cuda-toolkit-13-1

git clone --depth 1 --branch v0.7.0 https://github.com/ggml-org/llama.cpp /opt/src/llama.cpp
cd /opt/src/llama.cpp
cmake -B build-static -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86 \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda-13.1/bin/nvcc \
  -DGGML_RPC=OFF -DLLAMA_BUILD_TESTS=OFF
cmake --build build-static -j 6 --target llama-server llama-bench

install -d /opt/llama.cpp/v0.7.0/bin
install -m 0755 build-static/bin/llama-server build-static/bin/llama-bench /opt/llama.cpp/v0.7.0/bin/
ln -sfn /opt/llama.cpp/v0.7.0 /opt/llama.cpp/current
```

The static build keeps `libggml` and `libllama` inside the binary, so each
version is self-contained and a rollback is a symbolic link change. Only the
CUDA libraries stay dynamic. Built for `sm_86` only, the Ampere architecture
of both cards. The RPC backend is not built.

Check: `git rev-parse HEAD` matches the pinned commit,
`llama-server --list-devices` shows the RTX 3090, and
`ldd /opt/llama.cpp/current/bin/llama-server` resolves every library.

## 7. Model and API key

```bash
useradd --system --user-group --groups gpu --home-dir /var/lib/llama --shell /usr/sbin/nologin llama
install -d -o root -g llama -m 0750 /var/lib/llama /var/lib/llama/models /etc/llama
openssl rand -hex 32 > /etc/llama/api-key
chown root:llama /etc/llama/api-key && chmod 0640 /etc/llama/api-key

REV=4ca720788d1e01f1bff70c033e0d0028fd02e502
F=Qwen3.8-27B-UD-Q4_K_XL.gguf
wget -c -O /var/lib/llama/models/$F "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/$REV/$F"
echo "3f227079003add2511437e5b1e94812e363385225bf6a9b47b0054a72bc8b01e  /var/lib/llama/models/$F" | sha256sum -c -
chown root:llama /var/lib/llama/models/$F && chmod 0640 /var/lib/llama/models/$F
```

The service account can read the model and the key, but not change them. The
key never leaves the container and is not stored in this repository.

## 8. Service

Copy [`llama-server.service`](../../deploy/merlin/llm/llama-server.service)
to `/etc/systemd/system/`, then `systemctl daemon-reload` and
`systemctl enable --now llama-server`.

Settings, from [ADR 0006](../adr/0006-llama-server-runtime.md),
[ADR 0008](../adr/0008-gateway-caddy-mtls.md) and the model card:

- Loopback only, API key required, no web UI, no `/slots` endpoint, no
  built-in tools, metrics on.
- All layers on the GPU, one slot, 32K context, flash attention, `q8_0`
  key-value cache. The context size will be raised from measured memory use.
- Thinking-mode sampling from the model card: temperature 1.0, top-p 0.95,
  top-k 20, min-p 0.
- `-lm dio` loads the model with direct I/O. With the default memory map,
  the model file stays in the page cache, which is charged to the container:
  `systemctl status llama-server` showed 14.2 GB of its 16 GB limit, against
  1.1 GB with direct I/O.
- No image projector (`--mmproj`) yet: text only.
- The model's multi-token prediction head is loaded but unused; the server
  logs its tensors as unused. Speculative decoding is evaluated later.
- Systemd sandboxing: no privileges or capabilities, read-only file system.
  `MemoryDenyWriteExecute` is not set because the CUDA driver needs to map
  executable memory. Device filtering is done by the container, not by
  systemd.

## 9. Smoke test

```bash
scripts/smoke/llm.sh
```

The [script](../../scripts/smoke/llm.sh) checks that requests without a key
are rejected, that the model is listed under its alias, that a chat answer
stops normally with the reasoning in `reasoning_content`, and that a tool call
returns valid JSON arguments. It reads the key from a file and never puts it
on the command line.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `nvidia-smi: command not found` in the container | Commands pasted after `pct enter` are lost: run them one by one inside the container |
| `Field "minor_number" is not a valid field to query` | Not available in this driver; the device that a container receives identifies its card |
| Service briefly shown as `(a-server)` | systemd preparing the sandbox before `exec`; normal for a few milliseconds |
| Container memory close to its limit with the model on the GPU | Memory-mapped model in the page cache; use `-lm dio` |
| `jq: Cannot iterate over null` on `/v1/models` | Request without a valid key: the server returned an error |
