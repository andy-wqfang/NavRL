#!/usr/bin/env bash
set -euo pipefail

mkdir -p /workspace/docker

exec dockerd \
  --host=unix:///var/run/docker.sock \
  --data-root=/workspace/docker \
  --iptables=false \
  --bridge=none \
  --ip-forward=false \
  --ip-masq=false
