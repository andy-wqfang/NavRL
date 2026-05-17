# NavRL Resume Guide

This repository is now arranged so the expensive state lives under `/workspace`, which is the persistent mount on this Vast.ai setup.

## What already persists

- repo and local patches: `/workspace/projects/NavRL`
- Isaac Sim 4.2 extracted payload: `/workspace/downloads/isaac-sim-4.2.0-bundle`
- Isaac Sim link: `/workspace/isaac/isaac_sim-4.2.0`
- logs: `/workspace/logs/navrl_setup`
- checkpoints and WandB directories: `/workspace/checkpoints`, `/workspace/wandb`

## What does **not** naturally persist

- the active Conda environment at `/venv/NavRL`
- OS packages installed with `apt`
- root-shell settings under `/root`

Those are the pieces captured by the resume bundle below.

## Before shutting down this instance

Run:

```bash
cd /workspace/projects/NavRL
scripts/save_resume_bundle.sh
```

This writes a portable archive plus manifests under:

```text
/workspace/resume/navrl
```

## On a future fresh instance

Mount the same `/workspace`, then run:

```bash
cd /workspace/projects/NavRL
scripts/rehydrate_navrl_from_workspace.sh
```

Then verify the real training path:

```bash
scripts/run_isaac42_smoke.sh env.max_episode_length=20 max_frame_num=1
```

## What this buys you

You still need a reasonably compatible GPU host and base OS, but you should not need to:

- re-download Isaac Sim 4.2
- re-debug TorchRL/TensorDict ABI issues
- rediscover the 4.2 compatibility patches
- rebuild the Python environment from scratch unless you choose to

The durable workspace becomes the seed crystal; the next instance only has to regrow the thin shell around it.
