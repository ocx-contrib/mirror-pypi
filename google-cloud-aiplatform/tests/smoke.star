# tests/smoke.star — aiplatform is a LIBRARY (no console script of its own),
# so it is exercised by running the composed interpreter (the always-synthesized
# `python` entrypoint — `python`, not `python3`: python-build-standalone ships a
# python3 binary only on POSIX, while `python` resolves in-package everywhere,
# Windows included — which carries the env's PYTHONPATH) and importing the top
# namespace. A successful import proves the PEP 420 google.* namespace union
# resolved into one working env.

# Tier 1: liveness — the composed python runs and the import succeeds.
r = ocx.run("python", "-c", "import google.cloud.aiplatform as a; print(a.__version__)")
expect.ok(r)

# Tier 2: real output — the locked distribution version prints, proving the
# aiplatform package (not just an empty namespace shell) loaded.
expect.contains(r.stdout, "1.163.0")
