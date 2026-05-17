# NavRL Setup Notes

Date: 2026-05-16 UTC

## Current status

- Repository already present at `/workspace/projects/NavRL`.
- Physical working path resolves to `/workspace/projects/NavRL` even though the shell prints `/root/projects/NavRL`.
- Existing Conda environment found: `NavRL` at `/venv/NavRL`.
- GPU access works from the repaired `NavRL` environment.
- Local Python stack is now healthy:
  - `torch` imports and sees the RTX 4090
  - `tensordict` imports
  - `torchrl` imports
  - both local compiled extensions import cleanly
  - `wandb` is installed in a repo-compatible version
- Exact legacy target still unavailable:
  - Isaac Sim `2023.1.0-hotfix.1` is not present locally.
  - The README-recommended legacy image pull returns `not found` for the exact tag.
- Experimental newer-version path now works:
  - Isaac Sim `4.2.0` is installed at `/workspace/isaac/isaac_sim-4.2.0`.
  - `omni`, vendored Orbit, and the NavRL training stack all import under a shell-scoped compatibility setup.
  - A tiny headless training smoke completed successfully on Isaac Sim `4.2.0` on 2026-05-16:
    - environment construction succeeded
    - policy evaluation completed
    - the script saved a model at training step `0`
    - the simulator shut down cleanly

## Required first checks

Commands run:

```bash
nvidia-smi
df -h
python --version
which python
pip --version || true
conda --version || true
docker --version || true
ls -lah /workspace
mkdir -p /workspace/projects /workspace/isaac /workspace/checkpoints /workspace/wandb /workspace/logs /workspace/downloads
```

Summary:

- GPU: NVIDIA GeForce RTX 4090
- Driver: `570.124.04`
- Host CUDA shown by `nvidia-smi`: `12.8`
- Disk:
  - `/workspace`: 299G total, 299G available at check time
  - root overlay: 100G total, 83G available at check time
- Default Python before activation: `Python 3.12.13`
- Default Python path: `/venv/main/bin/python`
- Pip: `26.0.1`
- Conda: `26.1.1`
- Docker: not installed (`docker: command not found`)
- Ensured persistent directories:
  - `/workspace/projects`
  - `/workspace/isaac`
  - `/workspace/checkpoints`
  - `/workspace/wandb`
  - `/workspace/logs`
  - `/workspace/downloads`
  - `/workspace/logs/navrl_setup`

## Repository inspection

Commands run:

```bash
git status
find . -maxdepth 3 -name "README*" -o -name "setup.sh" -o -name "*.yml" -o -name "*.yaml"
sed -n '1,240p' README.md
sed -n '1,260p' isaac-training/setup.sh
sed -n '1,260p' isaac-training/setup_deployment.sh
```

Findings:

- Branch: `main`
- Untracked local files already present:
  - `AGENTS.md`
  - `navrl_paper.pdf`
- Relevant setup files found:
  - `README.md`
  - `isaac-training/setup.sh`
  - `isaac-training/setup_deployment.sh`
- README explicitly requires **Isaac Sim 2023.1.0-hotfix.1**.
- `isaac-training/setup.sh` creates a `NavRL` Conda env, links Orbit to `${ISAACSIM_PATH}`, installs Orbit, OmniDrones, local TensorDict, and local TorchRL.
- `isaac-training/setup_deployment.sh` creates a lighter `NavRL` env and pins:
  - `python=3.10`
  - `numpy==1.26.4`
  - `torch==2.0.1`
  - `torchvision==0.15.2`
  - `torchaudio==2.0.2`

## Existing Conda environment

Commands run:

```bash
conda env list
conda list -n NavRL --show-channel-urls
conda run -n NavRL python /tmp/probe_navrl_env.py
```

Environment inventory:

- `base` -> `/opt/miniforge3`
- `NavRL` -> `/venv/NavRL`
- active shell env at inspection time: `/venv/main`

Important installed versions inside `NavRL`:

- Python `3.10.20`
- Torch `2.1.2+cu121`
- TorchVision `0.16.2`
- TorchAudio `2.1.2`
- NumPy `2.2.6`
- TensorDict listed as `0.4.0+3725bcc`
- TorchRL listed as `0.4.0+3725bcc`

Probe result from `NavRL`:

```text
torch: OK 2.1.2+cu121
omni: FAIL ModuleNotFoundError: No module named 'omni'
torchrl: FAIL ModuleNotFoundError: No module named 'torchrl'
tensordict: FAIL ModuleNotFoundError: No module named 'tensordict'
torch cuda: 12.1
cuda available: True
device: NVIDIA GeForce RTX 4090
capability: (8, 9)
```

Additional warning observed:

```text
A module that was compiled using NumPy 1.x cannot be run in NumPy 2.2.6...
```

Interpretation:

- The pre-existing `NavRL` env was usable enough for GPU probing, but it was not initially a valid NavRL training env.
- Dependency state had drifted from the repository scripts and was corrected minimally rather than replaced wholesale.

### Repairs applied to the existing environment

1. Restored the repo-pinned NumPy version:

```bash
conda run -n NavRL python -m pip install 'numpy==1.26.4'
```

2. Reinstalled vendored TensorDict and TorchRL from the current checkout because their editable metadata still pointed at an old path:

```text
/root/NavRL/isaac-training/third_party/...
```

instead of the current workspace path:

```text
/workspace/projects/NavRL/isaac-training/third_party/...
```

3. Fixed a TorchRL binary ABI mismatch:

- Symptom:

```text
ImportError: ... torchrl/_torchrl.so: undefined symbol: _ZNK3c105Error4whatEv
```

- Cause:
  - The vendored `pyproject.toml` files declare an unpinned `torch` build dependency.
  - Modern editable installs can therefore build in an isolated env against a different Torch version than the runtime env.
- Fix:

```bash
cd /workspace/projects/NavRL/isaac-training/third_party/rl
rm -f torchrl/_torchrl.so
conda run -n NavRL python -m pip install --no-build-isolation --no-deps --force-reinstall -e .
```

4. Installed WandB because `training/scripts/train.py` imports it unconditionally even when the config uses `wandb.mode: offline`.

5. Immediately corrected the first WandB attempt:

- `pip install wandb` upgraded `pydantic` to `2.13.4`
- The repo explicitly pins `pydantic<2.0.0`
- Final compatible choice:

```bash
conda run -n NavRL python -m pip install --force-reinstall \
  'wandb==0.16.6' \
  'pydantic!=1.7,!=1.7.1,!=1.7.2,!=1.7.3,!=1.8,!=1.8.1,<2.0.0,>=1.6.2'
```

Final verified local versions:

- `torch 2.1.2+cu121`
- `numpy 1.26.4`
- `tensordict 0.4.0+3725bcc`
- `torchrl 0.4.0+3725bcc`
- `wandb 0.16.6`
- `pydantic 1.10.26`

## Isaac Sim status

Commands run:

```bash
find /workspace -maxdepth 4 -type f -name "python.sh" 2>/dev/null | grep -i isaac || true
find / -maxdepth 4 -type d -iname "*isaac*" 2>/dev/null | head -50
grep -n 'ISAACSIM_PATH' ~/.bashrc 2>/dev/null || true
```

Findings:

- No Isaac Sim installation found.
- `/workspace/isaac` exists but is empty.
- No `ISAACSIM_PATH` entry found in `~/.bashrc`.
- `isaac-training/third_party/orbit/_isaac_sim` does not yet exist.

### Docker / Isaac Sim recovery attempt

Installed:

```bash
apt install -y docker.io poppler-utils
```

Because this Vast.ai container does not permit normal bridge/iptables setup, Docker only starts successfully with:

```bash
dockerd \
  --host=unix:///var/run/docker.sock \
  --data-root=/workspace/docker \
  --iptables=false \
  --bridge=none \
  --ip-forward=false \
  --ip-masq=false
```

Then attempted the exact README command:

```bash
docker pull nvcr.io/nvidia/isaac-sim:2023.1.0-hotfix.1
```

Exact result:

```text
Error response from daemon: failed to resolve reference "nvcr.io/nvidia/isaac-sim:2023.1.0-hotfix.1": nvcr.io/nvidia/isaac-sim:2023.1.0-hotfix.1: not found
```

Per the repo caution and `AGENTS.md`, I did **not** switch versions casually. After the user explicitly asked whether newer Isaac Sim could be tried, I tested `4.2.0` first because it is the smaller migration step than `4.5.0`.

### Isaac Sim 4.2.0 experiment

Because Docker-based extraction is constrained inside this container, the successful install path used registry copy + OCI unpacking instead:

```bash
skopeo copy docker://nvcr.io/nvidia/isaac-sim:4.2.0 oci:/workspace/downloads/isaac-sim-4.2.0-oci:4.2.0
umoci unpack --image /workspace/downloads/isaac-sim-4.2.0-oci:4.2.0 /workspace/downloads/isaac-sim-4.2.0-bundle
ln -s /workspace/downloads/isaac-sim-4.2.0-bundle/rootfs/isaac-sim /workspace/isaac/isaac_sim-4.2.0
```

Initial 4.2 startup needed a few host libraries:

```bash
apt-get install -y libsm6 libxt6 libglu1-mesa
```

Validation results:

- Headless Isaac Sim 4.2 startup works.
- `omni.isaac.core` imports.
- `omni.isaac.kit` imports.
- 4.2 does **not** ship `omni.isaac.orbit`, but the vendored Orbit extension imports when its extension path is added to `PYTHONPATH`.
- Running `orbit.sh --conda NavRL42` was intentionally abandoned because 4.2's unpinned `environment.yml` started resolving a large modern dependency stack instead of preserving NavRL's repaired versions.
- The working path is therefore shell-scoped:
  1. activate `NavRL`
  2. source Isaac Sim 4.2's `setup_conda_env.sh`
  3. remove Isaac's bundled `omni.isaac.ml_archive/pip_prebundle` from `PYTHONPATH`
  4. prepend vendored Orbit + OmniDrones paths

Small 4.2 compatibility fixes applied in the repo:

1. `training/scripts/train.py`
   - convert Hydra config to a plain container before passing it to WandB.
2. `third_party/orbit/.../terrains/utils.py`
   - fall back to Matplotlib colormap lookup when newer `trimesh` rejects Orbit's historical `"turbo"` string.
3. `third_party/OmniDrones/omni_drones/views/__init__.py`
   - detect whether `ArticulationView.__init__` still accepts `enable_dof_force_sensors`
   - use the newer parent `initialize()` path on 4.2
   - accept the newer `usd=` pose-query keyword while preserving older behavior.

Additional lightweight runtime deps installed for the 4.2 path:

```bash
python -m pip install 'prettytable==3.3.0' hidapi 'gymnasium==0.29.0' trimesh 'pyglet<2'
```

Successful smoke command:

```bash
scripts/run_isaac42_smoke.sh
```

The helper itself was also validated with a shortened episode horizon:

```bash
scripts/run_isaac42_smoke.sh env.max_episode_length=20 max_frame_num=1
```

Equivalent expanded command:

```bash
cd /workspace/projects/NavRL/isaac-training
python training/scripts/train.py \
  headless=True \
  wandb.mode=disabled \
  env.num_envs=1 \
  env.num_obstacles=2 \
  env_dyn.num_obstacles=0 \
  max_frame_num=10 \
  eval_interval=999999 \
  save_interval=999999
```

Notes from the successful run:

- `env.max_episode_length` is `2200`, so the first evaluation intentionally rendered a long 2200-step rollout before exit.
- One PhysX warning appeared during evaluation:

```text
PxArticulationLink::setGlobalPose(): it is illegal to call this method if PxSceneFlag::eENABLE_DIRECT_GPU_API is enabled!
```

  It was non-fatal in the smoke run, but should be watched during longer training.

## Training entrypoint notes

Commands run:

```bash
grep -R "headless" -n isaac-training/training isaac-training/scripts isaac-training 2>/dev/null | head -50
grep -R "SimulationApp" -n isaac-training 2>/dev/null | head -50
```

Findings:

- `isaac-training/training/cfg/train.yaml` defines `headless: False`.
- `training/scripts/train.py` constructs `SimulationApp({"headless": cfg.headless, ...})`.
- The repo therefore supports Hydra-style headless override:

```bash
python training/scripts/train.py headless=True
```

## Paper note

- Local reference paper present at `navrl_paper.pdf`.
- `poppler-utils` was installed so the paper can now be inspected locally.
- Paper/code alignment spot-check:
  - The paper describes PPO training, separate static/dynamic obstacle representations, a Beta-distribution policy, and training with many parallel agents.
  - The current code reflects those same ideas in `training/scripts/ppo.py`, `training/scripts/env.py`, and `training/scripts/utils.py`.

## Errors encountered

1. Initial Docker absence:

```text
docker: command not found
```

2. Docker daemon failed with default networking inside this restricted container:

```text
failed to create NAT chain DOCKER ... Permission denied
```

3. Exact Isaac Sim legacy pull failed:

```text
nvcr.io/nvidia/isaac-sim:2023.1.0-hotfix.1: not found
```

4. Existing `NavRL` env had mismatched package state:
   - NumPy 2.x instead of repo-pinned 1.26.4
   - stale editable paths for TensorDict/TorchRL
   - TorchRL binary ABI mismatch until rebuilt with `--no-build-isolation`

5. First training launch attempt exposed a missing `wandb` package.

6. Before Isaac Sim 4.2 was installed, training reached the then-current blocker:

```text
ModuleNotFoundError: No module named 'omni'
```

7. Isaac Sim 4.2 compatibility issues found and fixed:
   - missing Linux libraries: `libSM.so.6`, `libXt.so.6`, `libGLU.so.1`
   - WandB rejected Hydra `DictConfig`
   - newer `trimesh` rejected Orbit's `"turbo"` colormap string
   - `ArticulationView.__init__` signature drift
   - newer pose APIs pass `usd=...`

## Smoke tests

Verified after repairs:

```text
torch cuda available: True
tensordict ok
torchrl ok
```

Training launch attempts:

1. Before installing WandB:

```text
ModuleNotFoundError: No module named 'wandb'
```

2. After WandB repair:

```text
ModuleNotFoundError: No module named 'omni'
```

3. After Isaac Sim 4.2 compatibility work:

```text
[NavRL]: evaluation done.
[NavRL]: model saved at training step:  0
```

## Helper scripts added

```bash
scripts/verify_navrl_env.sh
scripts/start_docker_no_bridge.sh
scripts/run_isaac42_smoke.sh
scripts/save_resume_bundle.sh
scripts/rehydrate_navrl_from_workspace.sh
```

- `verify_navrl_env.sh` prints the current Conda/PyTorch/import status and whether `ISAACSIM_PATH` is set.
- `start_docker_no_bridge.sh` starts Docker in the restricted-container mode that worked on this server. Keep that shell open while using Docker.
- `run_isaac42_smoke.sh` activates the working 4.2 shell setup and runs the tiny headless validation job that succeeded on this machine.
- `save_resume_bundle.sh` snapshots the working environment manifests plus a portable Conda archive under `/workspace/resume/navrl`.
- `rehydrate_navrl_from_workspace.sh` reinstalls the small OS package layer, restores `/venv/NavRL` when needed, recreates the Isaac Sim link, and verifies the Python stack.

## Persistent resume bundle

Created on 2026-05-17:

```text
/workspace/resume/navrl
```

Contents:

- portable Conda archive:

```text
/workspace/resume/navrl/envs/NavRL-conda-pack.tar.gz
```

- manifests:
  - exact Conda explicit spec
  - Conda no-build export
  - Pip freeze
  - apt package list
  - git HEAD / status / working-tree patch
  - key path manifest

Bundle size after packing:

```text
5.1G
```

Important nuance:

- `tensordict` and `torchrl` are editable installs pointing into the persistent repo checkout under `/workspace/projects/NavRL`.
- `conda-pack` therefore needed `--ignore-editable-packages`, which is safe here because the source tree itself is part of the persistent workspace.

Rehydrate flow for a future fresh instance:

```bash
cd /workspace/projects/NavRL
scripts/rehydrate_navrl_from_workspace.sh
scripts/run_isaac42_smoke.sh env.max_episode_length=20 max_frame_num=1
```

Validation completed on the current instance:

- `save_resume_bundle.sh` finished successfully.
- `rehydrate_navrl_from_workspace.sh` was executed successfully against the current machine and confirmed:
  - `torch 2.1.2+cu121`
  - `tensordict 0.4.0+3725bcc`
  - `torchrl 0.4.0+3725bcc`
  - `wandb 0.16.6`

See also:

```text
RESUME.md
```

## Next recommended actions

1. If strict paper-faithful reproduction is required, still obtain **Isaac Sim 2023.1.0-hotfix.1** from a source other than the now-missing legacy Docker tag.
2. If continuing on the practical newer-version path, use:

```bash
scripts/run_isaac42_smoke.sh
```

3. Before a long run, decide whether to:
   - leave WandB disabled, or
   - supply a WandB API key and switch `wandb.mode` back from `disabled`.
4. For longer 4.2 training, monitor the non-fatal PhysX direct-GPU warning above and run a longer low-cost validation before committing many GPU-hours.
5. If the exact legacy Isaac Sim tree becomes available later, set:

```bash
export ISAACSIM_PATH="/workspace/isaac/isaac_sim-2023.1.0-hotfix.1"
```

6. Then re-run:

```bash
scripts/verify_navrl_env.sh
```

7. Then use the repository's original setup path if returning to the legacy target:

```bash
cd /workspace/projects/NavRL/isaac-training
bash setup.sh
```

8. After `omni` imports successfully on the legacy target, try:

```bash
cd /workspace/projects/NavRL/isaac-training
conda activate NavRL
python training/scripts/train.py headless=True
```

## Key logs saved under `/workspace/logs/navrl_setup`

- `navrl_conda_explicit_before_20260516_170636.txt`
- `navrl_pip_freeze_before_20260516_170636.txt`
- `env_repair_20260516_170708.log`
- `torchrl_rebuild_20260516_172336.log`
- `torchrl_no_isolation_rebuild_20260516_172701.log`
- `system_packages_20260516_172353.log`
- `dockerd_20260516_172443.log`
- `dockerd_nobridge_20260516_172711.log`
- `docker_pull_isaac_2023_1_0_hotfix_1_20260516_172813.log`
- `smoke_tests_20260516_172859.log`
- `train_attempt_20260516_172900.log`
- `install_wandb_20260516_173243.log`
- `repair_wandb_pydantic_20260516_173400.log`
- `skopeo_copy_isaac_4_2_0_*.log`
- `umoci_unpack_isaac_4_2_0_*.log`
- `isaac42_smoke_after_hostlibs_*.log`
- `isaac42_orbit_import_probe_*.log`
- `navrl_env_isaac42_orbit_probe_*.log`
- `navrl_env_isaac42_train_order_probe_*.log`
- `install_orbit_runtime_deps_*.log`
- `train_isaac42_smoke_after_wandb_patch_*.log`
- `train_isaac42_smoke_after_orbit_deps_*.log`
- `train_isaac42_smoke_after_trimesh_patch_*.log`
- `train_isaac42_smoke_after_articulation_patch_*.log`
- `train_isaac42_smoke_after_pose_patch_20260516_190704.log`
- `run_isaac42_smoke_script_check_20260516_191225.log`
- `/workspace/resume/navrl/manifests/*`
