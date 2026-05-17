#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISAACSIM_PATH="${ISAACSIM_PATH:-/workspace/isaac/isaac_sim-4.2.0}"
CONDA_ENV_NAME="${CONDA_ENV_NAME:-NavRL}"

if [[ ! -f "${ISAACSIM_PATH}/setup_conda_env.sh" ]]; then
  echo "Isaac Sim setup script not found at: ${ISAACSIM_PATH}/setup_conda_env.sh" >&2
  exit 1
fi

eval "$(conda shell.bash hook)"
conda activate "${CONDA_ENV_NAME}"

export ISAACSIM_PATH
export ACCEPT_EULA="${ACCEPT_EULA:-Y}"
export PRIVACY_CONSENT="${PRIVACY_CONSENT:-Y}"

# Isaac Sim 4.2 prepends its own Python bundle. Keep its Omniverse packages,
# but remove the bundled ML archive so NavRL continues to use the repaired
# Torch/TorchRL stack from the Conda environment.
# Isaac's hook reads a few optional shell variables without guarding them,
# so temporarily relax nounset only while sourcing that external script.
set +u
source "${ISAACSIM_PATH}/setup_conda_env.sh"
set -u
if [[ -n "${PYTHONPATH:-}" ]]; then
  PYTHONPATH="$(
    printf '%s' "${PYTHONPATH}" \
      | tr ':' '\n' \
      | grep -v '/omni.isaac.ml_archive/pip_prebundle$' \
      | paste -sd: -
  )"
fi
export PYTHONPATH="${ROOT_DIR}/isaac-training/third_party/orbit/source/extensions/omni.isaac.orbit:${ROOT_DIR}/isaac-training/third_party/OmniDrones${PYTHONPATH:+:${PYTHONPATH}}"

cd "${ROOT_DIR}/isaac-training"
exec python training/scripts/train.py \
  headless=True \
  wandb.mode=disabled \
  env.num_envs=1 \
  env.num_obstacles=2 \
  env_dyn.num_obstacles=0 \
  max_frame_num=10 \
  eval_interval=999999 \
  save_interval=999999 \
  "$@"
