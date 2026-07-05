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

# linux/amd64: PBS's actual fully-static musl build (verified V1c) — no NEEDED
# entries, no ELF interpreter, runs unmodified on glibc AND musl hosts; cannot
# dlopen a compiled extension (Py_ENABLE_SHARED=0), so a `libc: musl` variant
# using this interpreter MUST also set `wheel_priority: ["any"]`.
# linux/arm64: PBS ships NO `+static` musl build for aarch64 at any CPython
# version (checked the full 20260623 release asset list) — stays on the
# dynamic `install_only` build, unchanged from before. This arm64 interpreter
# therefore keeps V1a's original limitation (works only inside a musl-libc
# container, not on a bare glibc host) — not universal on this platform.
declare -A ASSET=(
  [linux/amd64]="cpython-${VERSION}+${PBS_TAG}-x86_64-unknown-linux-musl-lto+static-full.tar.zst"
  [linux/arm64]="cpython-${VERSION}+${PBS_TAG}-aarch64-unknown-linux-musl-install_only.tar.gz"
)

first=1
for platform in linux/amd64 linux/arm64; do
  file="${WORK}/${ASSET[$platform]}"
  echo ">> downloading ${ASSET[$platform]}"
  curl -fsSL -o "${file}" "${BASE}/${ASSET[$platform]}"

  if [ "${platform}" = "linux/amd64" ]; then
    # The `+static-full` tarball's top level is python/{build,install,licenses,
    # PYTHON.json} — build/ alone is ~100MB of compiled .o object files. A
    # plain `strip=2` component-strip (like install_only gets) would dump
    # build/ and licenses/ at the package root next to bin/ (confirmed by
    # inspecting member sizes: python/build = 104.5MB uncompressed). Repack
    # just the ready-to-use python/install/ subtree so the package root stays
    # bin/include/lib/share only, matching install_only's shape.
    extract_dir="${WORK}/extract-${platform//\//-}"
    mkdir -p "${extract_dir}"
    tar -xf "${file}" -C "${extract_dir}" python/install
    push_file="${WORK}/repacked-${platform//\//-}.tar.gz"
    tar -czf "${push_file}" -C "${extract_dir}/python" install
    strip=1
  else
    # install_only extracts flat as python/{bin,lib,...} — strip=1 as before.
    push_file="${file}"
    strip=1
  fi

  if [ "${first}" = 1 ]; then
    ocx package push --cascade --new -p "${platform}" -i "${REPO}:${VERSION}" -m "${META}" "${push_file}:strip=${strip}"
    first=0
  else
    ocx package push --cascade -p "${platform}" -i "${REPO}:${VERSION}" -m "${META}" "${push_file}:strip=${strip}"
  fi
done

rm -rf "${WORK}"
echo ">> published ${REPO}:${VERSION} (linux/amd64 + linux/arm64, musl)"
ocx --remote package inspect "${REPO}:${VERSION}"
