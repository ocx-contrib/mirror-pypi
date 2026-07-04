# tests/yt-dlp.smoke.star — yt-dlp is a single pure-python wheel. Assert the
# console-script shim runs and prints its calendar version (no network I/O).

# Tier 1: liveness — the composed `yt-dlp` console-script shim runs.
r = ocx.run("yt-dlp", "--version")
expect.ok(r)

# Tier 2: real output — `--version` prints the locked calendar version,
# proving the entrypoint dispatched into yt_dlp.main, not an empty shim.
# yt-dlp zero-pads its internal __version__ (2026.06.09) vs the PyPI-normalized
# tag 2026.6.9 the package is published under — assert the runtime form.
expect.contains(r.stdout, "2026.06.09")
