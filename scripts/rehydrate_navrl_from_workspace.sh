#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="${BUNDLE_DIR:-/workspace/resume/navrl}"
ENV_ARCHIVE="${BUNDLE_DIR}/envs/NavRL-conda-pack.tar.gz"
ENV_PREFIX="${ENV_PREFIX:-/venv/NavRL}"
ISAAC_TARGET="/workspace/isaac/isaac_sim-4.2.0"
ISAAC_SOURCE="/workspace/downloads/isaac-sim-4.2.0-bundle/rootfs/isaac-sim"

if [[ ! -f "${ENV_ARCHIVE}" ]]; then
  echo "Missing environment archive: ${ENV_ARCHIVE}" >&2
  exit 1
fi

echo "== installing OS packages needed by this setup =="
apt-get update
apt-get install -y \
  docker.io \
  poppler-utils \
  skopeo \
  umoci \
  jq \
  libsm6 \
  libxt6 \
  libglu1-mesa \
  xauth \
  x11-apps

echo "== restoring NavRL environment =="
if [[ -d "${ENV_PREFIX}" && -x "${ENV_PREFIX}/bin/python" ]]; then
  echo "Environment already exists at ${ENV_PREFIX}; leaving it in place."
else
  mkdir -p "${ENV_PREFIX}"
  tar -xzf "${ENV_ARCHIVE}" -C "${ENV_PREFIX}"
  "${ENV_PREFIX}/bin/conda-unpack"
fi

echo "== restoring Isaac Sim workspace link =="
if [[ ! -d "${ISAAC_SOURCE}" ]]; then
  echo "Missing Isaac Sim payload at ${ISAAC_SOURCE}" >&2
  exit 1
fi
mkdir -p "$(dirname "${ISAAC_TARGET}")"
ln -sfn "${ISAAC_SOURCE}" "${ISAAC_TARGET}"

echo "== quick environment check =="
"${ENV_PREFIX}/bin/python" - <<'PY'
import torch
import tensordict
import torchrl
import wandb

print("torch:", torch.__version__)
print("torch cuda:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())
print("tensordict:", tensordict.__version__)
print("torchrl:", torchrl.__version__)
print("wandb:", wandb.__version__)
PY

cat <<EOF

Rehydrate complete.

Next commands:
  cd "${ROOT_DIR}"
  scripts/run_isaac42_smoke.sh env.max_episode_length=20 max_frame_num=1

If that passes, use the normal longer-running training command you want.
EOF
