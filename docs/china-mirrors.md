# China Mirror Mode for jetson-containers

This document describes how to use the `--china` option to build images in Mainland China with popular mirrors for apt, pip, npm and HuggingFace.

## What it does

When you pass `--china` to the build command:

- Dynamically rewrites the Dockerfile used during `docker build` by inserting a small block right after the first `FROM` (keeping Dockerfile unchanged on disk). The rewritten file is saved as `Dockerfile-cn` alongside the original and used just for the build.
- Adds optional build-args for common CN mirrors and appends `-cn` to the image tag so you can distinguish mirror-based builds.

Injected block sets:

- APT mirror (Tsinghua by default) by replacing Ubuntu archive URLs and running `apt-get update`.
- pip index-url and trusted-host.
- npm registry.
- HuggingFace endpoint and enables HF_TRANSFER.

This process is idempotent and safe: if the `Dockerfile-cn` already exists and contains our marker, it'll be reused.

## Usage

- Build a single container with China mirrors:

```bash
./jetson-containers build --china pytorch
```

- Build multiple images (batch mode):

```bash
./jetson-containers build --china --multiple llm/*
```

- Combine with custom base/name as usual:

```bash
./jetson-containers build --china --name myrepo/edge-ml pytorch jupyterlab
```

Result tags will include `-cn` suffix (e.g., `myrepo/edge-ml:...-cn`).

## Customizing mirrors

Override via environment variables or `--build-args` (they merge):

- `APT_MIRROR` (default: `https://mirrors.tuna.tsinghua.edu.cn/ubuntu`)
- `PIP_INDEX_URL` (default: `https://pypi.tuna.tsinghua.edu.cn/simple`)
- `PIP_TRUSTED_HOST` (default: `pypi.tuna.tsinghua.edu.cn`)
- `NPM_REGISTRY` (default: `https://registry.npmmirror.com`)
- `HF_ENDPOINT` (default: `https://hf-mirror.com`)

Examples:

```bash
export APT_MIRROR=https://mirrors.ustc.edu.cn/ubuntu
export HF_ENDPOINT=https://hf-mirror.com
./jetson-containers build --china transformers
```

Or:

```bash
./jetson-containers build --china \
  --build-args APT_MIRROR:https://mirrors.aliyun.com/ubuntu,PIP_INDEX_URL:https://mirrors.aliyun.com/pypi/simple \
  onnxruntime
```

## Notes & Limitations

- Rewrites only occur for packages that have a Dockerfile. For stages that re-tag base images (without a Dockerfile), no rewrite is needed.
- The injection targets Ubuntu sources list paths commonly used. If some images customize apt sources differently, you can still set `APT_MIRROR` and the sed commands will no-op if patterns aren't found.
- If the original Dockerfile uses advanced multi-stage patterns with additional `FROM` lines later, we inject just after the first `FROM` to affect base layer setup. If you need later stages to also use mirrors, we can extend the injector to repeat after subsequent `FROM` lines.
- You can combine `--china` with `--use-proxy` if you also need corporate proxies.

## Troubleshooting

- If a build stage still tries to reach global hosts, confirm that the tool it's using respects the configured mirrors or add additional environment variables as build-args.
- Check the generated file next to the package Dockerfile (named `Dockerfile-cn`) to confirm the injection.
- Look in `logs/` for the exact docker build command used.
