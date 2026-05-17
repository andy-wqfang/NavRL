# AGENTS.md

You are an autonomous coding agent setting up and validating the NavRL repository on a remote Vast.ai GPU server.

## Goal

Build a working NavRL training environment on this machine, verify that the installation works, and leave behind clear notes/scripts so the user can reproduce or resume the setup later.

The target repository is:

```bash
https://github.com/Zhefan-Xu/NavRL.git
````

NavRL was developed against **Isaac Sim 2023.1.0-hotfix.1** and warns that other Isaac Sim versions may cause incompatibility. Follow the repository instructions first before improvising. The repo also depends on Orbit-era Isaac Sim tooling and TorchRL-style training infrastructure.

## Machine assumptions

The current server is a Vast.ai instance with:

* Ubuntu/Linux container environment
* NVIDIA GPU, likely RTX 4090
* CUDA visible through `nvidia-smi`
* `/workspace` mounted as the main large persistent working directory
* root access
* conda/uv base environment may already be active

Use `/workspace` for all persistent project files.

Recommended layout:

```bash
/workspace/projects
/workspace/isaac
/workspace/checkpoints
/workspace/wandb
/workspace/logs
/workspace/downloads
```

Do not store important work only under `/root` unless symlinked or copied to `/workspace`.

## High-level setup plan

1. Verify hardware and storage.
2. Clone NavRL into `/workspace/projects/NavRL`.
3. Read the repository README and setup scripts before running them.
4. Install or locate Isaac Sim 2023.1.0-hotfix.1.
5. Set `ISAACSIM_PATH`.
6. Run NavRL setup.
7. Activate the NavRL environment.
8. Run minimal smoke tests.
9. Run the default training script if possible.
10. Document every fix, command, and error in `/workspace/projects/NavRL/SETUP_NOTES.md`.

## Required first commands

Run these first and record output summaries in `SETUP_NOTES.md`:

```bash
nvidia-smi
df -h
python --version
which python
pip --version || true
conda --version || true
docker --version || true
```

Also check:

```bash
ls -lah /workspace
mkdir -p /workspace/projects /workspace/isaac /workspace/checkpoints /workspace/wandb /workspace/logs /workspace/downloads
```

## Repository setup

Clone only if it does not already exist:

```bash
cd /workspace/projects
git clone https://github.com/Zhefan-Xu/NavRL.git
cd /workspace/projects/NavRL
```

Before changing anything:

```bash
git status
find . -maxdepth 3 -name "README*" -o -name "setup.sh" -o -name "*.yml" -o -name "*.yaml"
```

Read the README and `isaac-training/setup.sh`.

## Isaac Sim requirement

NavRL expects:

```text
Isaac Sim 2023.1.0-hotfix.1
```

Expected environment variable:

```bash
export ISAACSIM_PATH="/workspace/isaac/isaac_sim-2023.1.0-hotfix.1"
```

Append this to shell startup only after confirming the path exists:

```bash
echo 'export ISAACSIM_PATH="/workspace/isaac/isaac_sim-2023.1.0-hotfix.1"' >> ~/.bashrc
```

If Isaac Sim is missing, attempt the repository-recommended Docker-based legacy download method. If the NGC image is unavailable, do not randomly switch Isaac Sim versions without noting the risk. Instead:

1. Search existing local paths:

   ```bash
   find /workspace -maxdepth 4 -type f -name "python.sh" 2>/dev/null | grep -i isaac || true
   find / -maxdepth 4 -type d -iname "*isaac*" 2>/dev/null | head -50
   ```

2. Try pulling the required container:

   ```bash
   docker pull nvcr.io/nvidia/isaac-sim:2023.1.0-hotfix.1
   ```

3. If unavailable, record the exact error in `SETUP_NOTES.md` and stop for user confirmation before porting to a newer Isaac Sim.

## Running NavRL setup

Preferred flow:

```bash
cd /workspace/projects/NavRL/isaac-training
bash setup.sh
```

Then:

```bash
conda activate NavRL
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0)); print(torch.version.cuda)"
```

If conda activation fails, inspect the setup script and environment files before editing.

## Compatibility rules

This project is legacy-version-sensitive.

Do:

* Prefer exact versions from the repo.
* Keep a log of all dependency changes.
* Make minimal fixes.
* Test after each fix.
* Keep patch changes small and reversible.

Do not:

* Upgrade Isaac Sim casually.
* Upgrade all packages blindly.
* Replace Orbit with Isaac Lab unless explicitly asked.
* Rewrite the training framework.
* Delete repo files or checkpoints.
* Store large generated files in git.
* Commit secrets, tokens, SSH keys, or Vast credentials.

## RTX 4090 / CUDA caution

The machine may show a newer host driver/CUDA through `nvidia-smi`, such as CUDA 12.8 or 13.0. This is not necessarily the same as the CUDA used by PyTorch inside the environment.

After setup, verify PyTorch GPU support:

```bash
python - <<'PY'
import torch
print("torch:", torch.__version__)
print("torch cuda:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device:", torch.cuda.get_device_name(0))
    print("capability:", torch.cuda.get_device_capability(0))
PY
```

If Torch cannot use the GPU, fix PyTorch only after checking the repo requirements. Record the original version first.

## Smoke tests

After setup, run lightweight checks before full training:

```bash
cd /workspace/projects/NavRL/isaac-training
conda activate NavRL

python -c "import torch; print(torch.cuda.is_available())"
python -c "import omni; print('omni import ok')" || true
python -c "import torchrl; print('torchrl ok')" || true
```

Then try the repo’s default training command:

```bash
python training/scripts/train.py
```

If GUI fails, try to identify whether the script supports headless mode. Search:

```bash
grep -R "headless" -n training scripts . | head -50
grep -R "SimulationApp" -n . | head -50
```

Do not assume a flag name; inspect code/config first.

## Logging

Create and continuously update:

```bash
/workspace/projects/NavRL/SETUP_NOTES.md
```

Include:

* Server GPU/driver/CUDA summary
* Disk layout
* Isaac Sim path
* Exact commands run
* Errors encountered
* Fixes applied
* Current status
* Next recommended action

Also save long logs under:

```bash
/workspace/logs/navrl_setup/
```

Example:

```bash
mkdir -p /workspace/logs/navrl_setup
bash setup.sh 2>&1 | tee /workspace/logs/navrl_setup/setup_$(date +%Y%m%d_%H%M%S).log
```

## If something fails

When an error occurs:

1. Copy the exact command and traceback into `SETUP_NOTES.md`.
2. Identify the failing layer:

   * Isaac Sim path/version
   * Orbit import
   * Torch/TorchRL import
   * CUDA/PyTorch compatibility
   * Missing Linux package
   * Python package version conflict
3. Apply the smallest likely fix.
4. Re-run the smallest test that reproduces the issue.
5. Stop and ask the user before making large architectural changes.

## Definition of done

The task is complete when at least one of these is true:

### Ideal completion

* `conda activate NavRL` works
* Isaac Sim 2023.1.0-hotfix.1 is found via `ISAACSIM_PATH`
* PyTorch sees the GPU
* NavRL imports work
* `python training/scripts/train.py` starts successfully
* Setup notes are complete

### Acceptable partial completion

If the exact Isaac Sim legacy image is unavailable or a hard compatibility issue blocks progress:

* The blocker is clearly documented
* All attempted commands are logged
* The repo is cloned and inspected
* A minimal next-step recommendation is written

## Communication style

Be conservative, precise, and reproducible. Prefer one working setup over many speculative fixes.

```
::contentReference[oaicite:0]{index=0}
```
