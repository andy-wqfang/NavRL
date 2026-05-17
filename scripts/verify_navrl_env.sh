#!/usr/bin/env bash
set -euo pipefail

eval "$(conda shell.bash hook)"
conda activate NavRL

echo "== NavRL environment =="
python --version
which python

python - <<'PY'
import importlib
import os
import torch

for name in ["torch", "tensordict", "torchrl", "wandb"]:
    mod = importlib.import_module(name)
    print(f"{name}: {getattr(mod, '__version__', 'ok')}")

print("torch cuda:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device:", torch.cuda.get_device_name(0))
    print("capability:", torch.cuda.get_device_capability(0))

isaac_path = os.environ.get("ISAACSIM_PATH")
print("ISAACSIM_PATH:", isaac_path or "<unset>")

try:
    import omni  # noqa: F401
    print("omni: ok")
except Exception as exc:
    print(f"omni: FAIL {type(exc).__name__}: {exc}")
PY
