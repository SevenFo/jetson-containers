# China Mirror Support – Design & Plan

Goal: Add a `--china` switch to `jetson-containers build` that dynamically injects China mirrors for apt/pip/npm/HuggingFace into Dockerfiles at build-time, without modifying source Dockerfiles, and produce images with `-cn` suffix tags.

## Requirements

- New CLI flag: `--china`
- No changes to source Dockerfiles required; create a sibling `Dockerfile-cn` used only for builds.
- Automatically append `-cn` to output image tag; compatible with names that already include tags.
- Provide defaults, but allow overrides via env or `--build-args`.
- Keep behavior idempotent and optional; when off, builds behave exactly the same.
- Minimal risk across many packages; default to injecting a small, generic block after the first `FROM`.

## Architecture

- Parse CLI in `jetson_containers/build.py` and forward `china=True` to container build routines. When enabled, populate default `build_args` values if not present.
- In `jetson_containers/container.py`:
  - Add `_inject_cn_mirrors()` that reads the package Dockerfile, inserts a mirror block immediately after the first `FROM` (skipping nearby ARG lines), writes `Dockerfile-cn`, and returns its path. The block includes configurable `ARG` and `ENV` entries and small `RUN` commands to switch mirrors.
  - Update build flow to select the CN Dockerfile when `china=True`.
  - Append `-cn` to final tag; intermediate stage tags inherit base `name` so they also reflect CN tagging.

## Mirror defaults (overridable)

- `APT_MIRROR`: `https://mirrors.tuna.tsinghua.edu.cn/ubuntu`
- `PIP_INDEX_URL`: `https://pypi.tuna.tsinghua.edu.cn/simple`
- `PIP_TRUSTED_HOST`: `pypi.tuna.tsinghua.edu.cn`
- `NPM_REGISTRY`: `https://registry.npmmirror.com`
- `HF_ENDPOINT`: `https://hf-mirror.com`

Users can override via environment or `--build-args` (merged later).

## Edge cases & risks

- Multi-stage Dockerfiles: we inject after the first `FROM` only. If later stages need mirrors, we can extend to find and inject after additional `FROM` lines.
- Non-Ubuntu images or custom apt sources files: sed replacements are guarded and no-op if patterns are absent.
- Some Dockerfiles might rewrite pip config later; mirrors are set early but may get overridden. Users can pass custom `--build-args` or we enhance detection later.
- Detached environments: CLI auto-installs Python deps; if PEP 668 blocks system pip, advise using project `install.sh` which sets up a venv (already present) or pass `--use-proxy` if corporate proxies are needed.

## Next steps

- Field-test on representative packages (pytorch, transformers, opencv) to ensure block insertion is compatible.
- Optionally extend to rewrite apt sources files explicitly for Debian variants.
- Add `--china-mirror-profile` for presets (tsinghua/ustc/aliyun/custom) if needed later.

## Usage examples

See `docs/china-mirrors.md`.
