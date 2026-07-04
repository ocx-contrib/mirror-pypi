# tests/streamlit.smoke.star — streamlit over the heavy C-ext stack. The
# `streamlit --version` path imports the top package, which transitively loads
# the compiled numpy/pandas/pyarrow wheels — proving the many-layer union
# composed and every compiled extension resolves at runtime.

# Tier 1: liveness — the composed `streamlit` console-script shim runs.
r = ocx.run("streamlit", "--version")
expect.ok(r)

# Tier 2: real output — `streamlit --version` prints `Streamlit, version X`,
# proving the shim dispatched into streamlit.web.cli:main and the compiled
# numpy/pandas/pyarrow layers imported.
expect.contains(r.stdout, "Streamlit")
expect.contains(r.stdout, "1.58.0")
