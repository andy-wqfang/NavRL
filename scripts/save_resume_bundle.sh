#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="${BUNDLE_DIR:-/workspace/resume/navrl}"
MANIFEST_DIR="${BUNDLE_DIR}/manifests"
ENV_ARCHIVE="${BUNDLE_DIR}/envs/NavRL-conda-pack.tar.gz"

mkdir -p "${MANIFEST_DIR}" "$(dirname "${ENV_ARCHIVE}")"

echo "== writing manifests to ${MANIFEST_DIR} =="
conda list -n NavRL --explicit > "${MANIFEST_DIR}/navrl-conda-explicit.txt"
conda env export -n NavRL --no-builds > "${MANIFEST_DIR}/navrl-conda-env-no-builds.yml"
conda run -n NavRL python -m pip freeze > "${MANIFEST_DIR}/navrl-pip-freeze.txt"
dpkg-query -W -f='${Package} ${Version}\n' \
  docker.io \
  poppler-utils \
  skopeo \
  umoci \
  jq \
  libsm6 \
  libxt6 \
  libglu1-mesa \
  xauth \
  x11-apps \
  2>/dev/null > "${MANIFEST_DIR}/apt-packages.txt" || true

git -C "${ROOT_DIR}" rev-parse HEAD > "${MANIFEST_DIR}/navrl-git-head.txt"
git -C "${ROOT_DIR}" status --short > "${MANIFEST_DIR}/navrl-git-status.txt"
git -C "${ROOT_DIR}" diff > "${MANIFEST_DIR}/navrl-working-tree.patch"

cat > "${MANIFEST_DIR}/paths.txt" <<EOF
repo=${ROOT_DIR}
conda_env=/venv/NavRL
isaac_sim=/workspace/isaac/isaac_sim-4.2.0
isaac_bundle=/workspace/downloads/isaac-sim-4.2.0-bundle/rootfs/isaac-sim
EOF

echo "== packing /venv/NavRL to ${ENV_ARCHIVE} =="
# TensorDict and TorchRL are intentionally editable installs pointing into the
# persisted repo checkout, so skip conda-pack's guard for those two packages.
conda-pack -p /venv/NavRL -o "${ENV_ARCHIVE}" --force --ignore-editable-packages

echo "== bundle summary =="
du -sh "${BUNDLE_DIR}"
find "${BUNDLE_DIR}" -maxdepth 3 -type f -printf '%TY-%Tm-%Td %TH:%TM %p\n' | sort
