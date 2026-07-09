#!/usr/bin/env bash
# Publish a multi-platform CPython interpreter to dev.ocx.sh with PER-LIBC
# linux entries (python-mirror-v2: libc is an `os.features` platform axis).
#
# One repo, one tag, one image index:
#   linux/amd64+libc.glibc  — PBS gnu install_only (dynamic glibc)
#   linux/amd64+libc.musl   — PBS musl install_only (dynamic musl)
#   darwin/arm64            — PBS darwin install_only
#   windows/amd64           — PBS windows-msvc install_only
#
# ocx >= 0.4.2 clients select the linux entry by host libc via `can_run`
# subset matching on `os.features`, so a single `python.interpreter_package`
# reference serves glibc AND musl hosts — no static build, no separate
# cpython-musl repo, no per-variant override. Supersedes
# publish-cpython-musl.sh's one-repo-per-libc convention for env packages.
#
# WHY a direct push and not a corpus mirror spec: python-build-standalone
# tags releases by DATE (20260623), so `github_release` tag->version mapping
# cannot produce a `3.14.6` tag — the version lives in the asset name.
#
# Requires: docker login to dev.ocx.sh and the `ocx` CLI on PATH.
# Idempotent: content-addressed push.
set -euo pipefail

VERSION="3.14.6"
PBS_TAG="20260623"
BASE="https://github.com/astral-sh/python-build-standalone/releases/download/${PBS_TAG}"
REPO="dev.ocx.sh/ocx/cpython"
DIR="$(dirname "$0")"
META_POSIX="${DIR}/cpython-musl-metadata.json"          # PATH=${installPath}/bin
META_WINDOWS="${DIR}/cpython-windows-metadata.json"     # PATH=${installPath} (python.exe at root)
WORK="$(mktemp -d)"

declare -A ASSET=(
  ["linux/amd64+libc.glibc"]="cpython-${VERSION}+${PBS_TAG}-x86_64-unknown-linux-gnu-install_only.tar.gz"
  ["linux/amd64+libc.musl"]="cpython-${VERSION}+${PBS_TAG}-x86_64-unknown-linux-musl-install_only.tar.gz"
  ["darwin/arm64"]="cpython-${VERSION}+${PBS_TAG}-aarch64-apple-darwin-install_only.tar.gz"
  ["windows/amd64"]="cpython-${VERSION}+${PBS_TAG}-x86_64-pc-windows-msvc-install_only.tar.gz"
)

first=1
for platform in "linux/amd64+libc.glibc" "linux/amd64+libc.musl" "darwin/arm64" "windows/amd64"; do
  file="${WORK}/${ASSET[$platform]}"
  echo ">> downloading ${ASSET[$platform]}"
  curl -fsSL -o "${file}" "${BASE}/${ASSET[$platform]}"

  meta="${META_POSIX}"
  if [ "${platform}" = "windows/amd64" ]; then
    meta="${META_WINDOWS}"
    # PBS windows install_only ships python.exe but NO python3.exe — while
    # every composed env entrypoint dispatches `python3`. Without it, PATH
    # resolution falls through to the WindowsApps Store-alias stub
    # (python3.exe), which hangs when spawned with piped stdio in CI.
    # Repack with a python3.exe copy so the composed PATH wins.
    extract_dir="${WORK}/extract-windows"
    mkdir -p "${extract_dir}"
    tar -xzf "${file}" -C "${extract_dir}" python
    cp "${extract_dir}/python/python.exe" "${extract_dir}/python/python3.exe"
    file="${WORK}/repacked-windows.tar.gz"
    tar -czf "${file}" -C "${extract_dir}" python
  fi

  # install_only extracts flat as python/{bin,lib,...} (posix) or
  # python/{python.exe,Lib,...} (windows) — strip=1 either way.
  if [ "${first}" = 1 ]; then
    ocx package push --cascade --new -p "${platform}" -i "${REPO}:${VERSION}" -m "${meta}" "${file}:strip=1"
    first=0
  else
    ocx package push --cascade -p "${platform}" -i "${REPO}:${VERSION}" -m "${meta}" "${file}:strip=1"
  fi
done

rm -rf "${WORK}"
echo ">> published ${REPO}:${VERSION} (glibc+musl linux/amd64, darwin/arm64, windows/amd64)"
ocx --remote package inspect "${REPO}:${VERSION}"
