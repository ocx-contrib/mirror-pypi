# tests/black.smoke.star — black is mypyc-compiled; the cp314 manylinux wheel
# is unioned with 6 dep layers into the env. Assert the console-script shim
# runs the compiled binary and reports its own version.

# Tier 1: liveness — the composed `black` console-script shim runs.
r = ocx.run("black", "--version")
expect.ok(r)

# Tier 2: real output — the entrypoint dispatched into black and printed the
# locked version (26.5.1), proving the compiled wheel + deps composed and load.
expect.contains(r.stdout, "black")
expect.contains(r.stdout, "26.5.1")
