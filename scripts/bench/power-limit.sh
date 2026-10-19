#!/usr/bin/env bash
# Power-limit sweep for one GPU: at each limit, runs llama-bench in the
# container that owns the GPU and samples the board power from the host.
#
# Usage: scripts/bench/power-limit.sh <container id> <gpu> [watts...]
#   <gpu> is the nvidia-smi selector of the card passed to the container
#   (index, PCI bus ID or UUID). Default limits: 350 300 280 250.
# Environment:
#   BENCH_MODEL  model path in the container
#                default /var/lib/llama/models/Qwen3.8-27B-UD-Q4_K_XL.gguf
#   BENCH_BIN    default /opt/llama.cpp/current/bin/llama-bench
#   BENCH_REPS   repetitions per test (default 5)
#   BENCH_BUSY   GPU utilisation (%) above which a power sample counts (default 80)
#   BENCH_OUT    results directory (default power-limit-<UTC timestamp>)
# Runs on the Proxmox host as root. Requires pct, nvidia-smi and jq.
# llama-server is stopped in the container during the sweep; on exit the
# previous power limit is restored and the service restarted.
set -euo pipefail

usage() { sed -n '5,7p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
(( $# >= 2 )) || usage
ct=$1 gpu=$2
shift 2
watts=("$@")
(( ${#watts[@]} > 0 )) || watts=(350 300 280 250)

model="${BENCH_MODEL:-/var/lib/llama/models/Qwen3.8-27B-UD-Q4_K_XL.gguf}"
bin="${BENCH_BIN:-/opt/llama.cpp/current/bin/llama-bench}"
reps="${BENCH_REPS:-5}"
busy="${BENCH_BUSY:-80}"
out="${BENCH_OUT:-power-limit-$(date -u +%Y%m%dT%H%M%SZ)}"

for cmd in pct nvidia-smi jq; do
  command -v "$cmd" >/dev/null || { echo "missing dependency: $cmd" >&2; exit 2; }
done
(( EUID == 0 )) || { echo "run as root on the Proxmox host" >&2; exit 2; }

query() { # query <field>: one nvidia-smi field for the selected GPU
  nvidia-smi -i "$gpu" --query-gpu="$1" --format=csv,noheader,nounits
}

# The container must see exactly the selected card, and no other.
ct_uuid=$(pct exec "$ct" -- nvidia-smi --query-gpu=uuid --format=csv,noheader)
[[ "$ct_uuid" == "$(query uuid)" ]] \
  || { echo "container $ct does not see exactly GPU $gpu" >&2; exit 2; }

min=$(query power.min_limit) max=$(query power.max_limit) previous=$(query power.limit)
min=${min%.*} max=${max%.*} previous=${previous%.*}
for w in "${watts[@]}"; do
  if ! [[ "$w" =~ ^[0-9]+$ ]] || (( w < min || w > max )); then
    echo "limit $w W outside the card's range ($min-$max W)" >&2
    exit 2
  fi
done

service_was_active=0
if pct exec "$ct" -- systemctl is-active --quiet llama-server; then
  service_was_active=1
fi

sampler=
restore() {
  if [[ -n "$sampler" ]]; then kill "$sampler" 2>/dev/null || true; fi
  nvidia-smi -i "$gpu" -pl "$previous" >/dev/null \
    || echo "WARNING: could not restore the $previous W power limit" >&2
  if (( service_was_active )); then
    pct exec "$ct" -- systemctl start llama-server \
      || echo "WARNING: could not restart llama-server" >&2
  fi
}
trap restore EXIT

if (( service_was_active )); then
  pct exec "$ct" -- systemctl stop llama-server
fi
mkdir -p "$out"

bench() { # bench <label> <llama-bench test arguments...>
  local label=$1
  shift
  nvidia-smi -i "$gpu" --format=csv,noheader,nounits -lms 500 \
    --query-gpu=timestamp,power.draw,utilization.gpu,temperature.gpu,clocks.sm \
    >"$out/$label.power.csv" &
  sampler=$!
  # Same settings as the service: all layers on the GPU, flash attention,
  # q8_0 key-value cache, direct I/O.
  pct exec "$ct" -- "$bin" -m "$model" -ngl 99 -fa on -ctk q8_0 -ctv q8_0 \
    -lm dio -r "$reps" -o json "$@" >"$out/$label.json" 2>"$out/$label.log"
  kill "$sampler"
  wait "$sampler" 2>/dev/null || true
  sampler=
}

rate() { # rate <json>: mean and standard deviation in tokens/s
  jq -r '.[0] | "\(.avg_ts * 10 | round / 10) ± \(.stddev_ts * 10 | round / 10)"' "$1"
}

busy_power() { # busy_power <csv>: median board power (W) while the GPU is busy
  awk -F', *' -v busy="$busy" '$3 >= busy { print $2 }' "$1" | sort -n \
    | awk '{ v[NR] = $1 }
           END { if (NR == 0) { print "n/a"; exit }
                 printf "%.0f\n", NR % 2 ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2 }'
}

per_joule() { # per_joule <tokens/s> <watts>
  awk -v t="$1" -v p="$2" 'BEGIN { if (p + 0 > 0) printf "%.3f\n", t / p; else print "n/a" }'
}

emit() { echo "$@" | tee -a "$out/summary.md"; }

emit "GPU: $(query name), driver $(query driver_version)," \
  "default limit $(query power.default_limit) W"
emit "Model: $(basename "$model"), $reps repetitions per test," \
  "power = median of samples with GPU utilisation >= $busy %"
emit
emit "| Limit (W) | Prompt 512 (tok/s) | Power (W) | Generation 128 (tok/s) | Power (W) | Generation (tok/J) |"
emit "|---:|---:|---:|---:|---:|---:|"
for w in "${watts[@]}"; do
  nvidia-smi -i "$gpu" -pl "$w" >/dev/null
  bench "${w}W-pp" -p 512 -n 0
  bench "${w}W-tg" -p 0 -n 128
  tg_power=$(busy_power "$out/${w}W-tg.power.csv")
  emit "| $w | $(rate "$out/${w}W-pp.json") | $(busy_power "$out/${w}W-pp.power.csv")" \
    "| $(rate "$out/${w}W-tg.json") | $tg_power" \
    "| $(per_joule "$(jq '.[0].avg_ts' "$out/${w}W-tg.json")" "$tg_power") |"
done
emit
emit "llama.cpp build: $(jq -r '.[0].build_commit' "$out/${watts[0]}W-pp.json")"
echo "Results in $out/"
