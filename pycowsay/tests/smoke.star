# tests/smoke.star — pycowsay is the first-corpus pylock app: pure-python
# (py3-none-any), one console-script entrypoint, no compiled extensions.
# Mirrors mirror-cpython's tiered convention (liveness, then real output).

# Tier 1: liveness — the composed console-script shim runs at all.
r = ocx.run("pycowsay", "moo")
expect.ok(r)

# Tier 2: real computation — the entrypoint actually formatted the message
# into the cow's speech bubble, not just an empty/echo shim.
expect.contains(r.stdout, "moo")
expect.contains(r.stdout, "^__^")
