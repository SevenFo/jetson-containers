# China Mirror Mode for jetson-containers

This document describes how to use the `--china` option to build images in Mainland China with popular mirrors for apt, pip, npm and HuggingFace.

## What it does

When you pass `--china` to the build command:

- Dynamically rewrites the Dockerfile used during `docker build` by inserting a small block right after the first `FROM` (keeping Dockerfile unchanged on disk). The rewritten file is saved as `Dockerfile-cn` alongside the original and used just for the build.
- Adds optional build-args for common CN mirrors and appends `-cn` to the image tag so you can distinguish mirror-based builds.

Injected block sets:

- APT mirrors for both archive and ubuntu-ports (arm64) by replacing Ubuntu sources across `/etc/apt/sources.list` and `/etc/apt/sources.list.d/*.list|*.sources`, then `apt-get update`.
- pip index-url and trusted-host.
- npm registry.
- HuggingFace endpoint and enables HF_TRANSFER.
- GitHub access acceleration (see below).

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

- `APT_MIRROR` (default: `http://mirrors.tuna.tsinghua.edu.cn/ubuntu`)
- `APT_MIRROR_PORTS` (default: `http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports`)
- `PIP_INDEX_URL` (default: `https://pypi.tuna.tsinghua.edu.cn/simple`)
- `PIP_TRUSTED_HOST` (default: `pypi.tuna.tsinghua.edu.cn`)
- `NPM_REGISTRY` (default: `https://registry.npmmirror.com`)
- `HF_ENDPOINT` (default: `https://hf-mirror.com`)
- `APT_INSECURE` (optional: when set, disables HTTPS cert verification for apt)
- `GITHUB_PROXY` (default: `https://gh-proxy.com/`)
- `GITHUB_PROXY_RAW` (default: same as `GITHUB_PROXY` unless overridden)
- `GITHUB_GITCONFIG` (default: `0` - set `1` to also write git global url rewrites in images)

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

## GitHub 加速（重要）

`--china` 模式下会对 Dockerfile 中从 GitHub 下载/克隆的行为进行统一重写，无需修改原始 Dockerfile：

- 覆盖的链接形态：
  - 分支源码：`https://github.com/<org>/<repo>/archive/refs/heads/<branch>.zip`
  - Release 源码/文件：`https://github.com/<org>/<repo>/archive/refs/tags/vX.Y.Z.zip`、`https://github.com/<org>/<repo>/releases/download/...`
  - 原始文件：`https://raw.githubusercontent.com/...`、`https://github.com/.../blob/...`（注意 blob 页面并非原始文件，建议使用 raw）
  - Gist：`https://gist.githubusercontent.com/.../raw/...`
  - API：`https://api.github.com/...`
  - codeload/objects：`https://codeload.github.com/...`、`https://objects.githubusercontent.com/...`
- 覆盖的命令/指令：`ADD`、`RUN` 中的 `curl`/`wget`、`git clone`/`pip` 中的 URL 字面量。
- 还会将 `git@github.com:`、`ssh://git@github.com/`、`git://github.com/` 自动转换为 `https://github.com/`，再走代理。
- 默认不写 git 的 global config；如需写入（例如内部脚本调用不方便被正则命中），可传 `--build-args GITHUB_GITCONFIG:1`。

可自定义代理：

```bash
./jetson-containers build --china \
  --build-args GITHUB_PROXY:https://mirror.ghproxy.com/,GITHUB_PROXY_RAW:https://raw.fgit.ml/ \
  ros:humble-ros-base
```

常见可选代理前缀（任选其一，注意尾部斜杠）：

- `https://gh-proxy.com/`（默认）
- `https://mirror.ghproxy.com/`
- `https://github.com.cnpmjs.org/`
- `https://hub.fgit.ml/`
- `https://gh.api.99988866.xyz/`

## Notes & Limitations

- Rewrites only occur for packages that have a Dockerfile. For stages that re-tag base images (without a Dockerfile), no rewrite is needed.
- The injection targets Ubuntu sources list paths commonly used. If some images customize apt sources differently, you can still set `APT_MIRROR` and the sed commands will no-op if patterns aren't found.
- If the original Dockerfile uses advanced multi-stage patterns with additional `FROM` lines later, we inject just after the first `FROM` to affect base layer setup. If you need later stages to also use mirrors, we can extend the injector to repeat after subsequent `FROM` lines.
- You can combine `--china` with `--use-proxy` if you also need corporate proxies.

## Troubleshooting

- If a build stage still tries to reach global hosts, confirm that the tool it's using respects the configured mirrors or add additional environment variables as build-args. For不可控的 shell 脚本，考虑开启 `GITHUB_GITCONFIG=1` 以防漏网。
- Check the generated file next to the package Dockerfile (named `Dockerfile-cn`) to confirm the injection.
- Look in `logs/` for the exact docker build command used.
