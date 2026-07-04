#!/usr/bin/env bash
# Publish a musl-libc CPython interpreter to dev.ocx.sh for the alpine/musl
# container test legs (goal_pylock_mirror.md finalization item 2).
#
# WHY this is a direct push and not a corpus mirror spec:
#   - python-build-standalone tags releases by DATE (e.g. 20260623), not by
#     Python version, so the `github_release` source's tag->version mapping
#     can't produce a `3.14.6` tag; the version lives in the asset name.
#   - A musl interpreter cannot be smoke-tested on the glibc GitHub runner, so
#     it can't go through the corpus test-gated pipeline natively. Its real
#     validation is transitive: the alpine pycowsay `libc: musl` leg pulls and
#     runs it end-to-end.
#
# ONE-WAY-DOOR CONVENTION (D4 v1 libc-variant grammar):
#   The musl interpreter lives in a SEPARATE repo `dev.ocx.sh/ocx/cpython-musl`
#   (not a platform-key axis on `cpython` — OCX platform keys are os/arch only;
#   musl vs gnu is a libc VARIANT). Corpus `libc: musl` variants set
#   `interpreter_package: dev.ocx.sh/ocx/cpython-musl:3.14.6`.
#
# Requires: docker login to dev.ocx.sh (ocx uses the docker credential
# fallback) and the `ocx` CLI on PATH. Idempotent: content-addressed push.
set -euo pipefail

VERSION="3.14.6"
PBS_TAG="20260623"
BASE="https://github.com/astral-sh/python-build-standalone/releases/download/${PBS_TAG}"
REPO="dev.ocx.sh/ocx/cpython-musl"
META="$(dirname "$0")/cpython-musl-metadata.json"
WORK="$(mktemp -d)"

declare -A ASSET=(
  [linux/amd64]="cpython-${VERSION}+${PBS_TAG}-x86_64-unknown-linux-musl-install_only.tar.gz"
  [linux/arm64]="cpython-${VERSION}+${PBS_TAG}-aarch64-unknown-linux-musl-install_only.tar.gz"
)

first=1
for platform in linux/amd64 linux/arm64; do
  file="${WORK}/${ASSET[$platform]}"
  echo ">> downloading ${ASSET[$platform]}"
  curl -fsSL -o "${file}" "${BASE}/${ASSET[$platform]}"
  # install_only tarballs extract under a top-level `python/` dir; strip=1 drops
  # it so `bin/python3` lands at the package root and PATH=${installPath}/bin resolves.
  if [ "${first}" = 1 ]; then
    ocx package push --cascade --new -p "${platform}" -i "${REPO}:${VERSION}" -m "${META}" "${file}:strip=1"
    first=0
  else
    ocx package push --cascade -p "${platform}" -i "${REPO}:${VERSION}" -m "${META}" "${file}:strip=1"
  fi
done

rm -rf "${WORK}"
echo ">> published ${REPO}:${VERSION} (linux/amd64 + linux/arm64, musl)"
ocx --remote package inspect "${REPO}:${VERSION}"
