#!/usr/bin/env bash
#
# setup_env.sh
#
# Sets up the pipenv virtual environment for this project, following
# "Python Setup in AI Perception Lab 2/401" (Muntzinger/Staub).
#
# Run this from inside the cloned repo (it acts as your "PythonProjects"
# folder - no need to create a separate one, the Pipfile already lives here).
#
# This script only sets up Python + pipenv + the .venv. Installing VSCodium,
# its Python/Jupyter extensions, and selecting the .venv kernel are NOT
# automated here - do those manually on the machine you work on, as shown
# in the PDF (steps 10-19).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

echo "==> Working in: $REPO_DIR"

# 1. Check for python3
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found. Install Python 3.12 first (pre-installed in 2/401, 'potentially install it on your own PC at home' otherwise)." >&2
    exit 1
fi

PY_VERSION="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
if [ "$PY_VERSION" != "3.12" ]; then
    echo "WARNING: python3 reports version $PY_VERSION, this project expects 3.12." >&2
fi

# 2. Check for / install pipenv
if ! command -v pipenv >/dev/null 2>&1; then
    echo "==> pipenv not found, installing it for the current user..."
    python3 -m pip install --user pipenv
    export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v pipenv >/dev/null 2>&1; then
    echo "ERROR: pipenv was installed but is not on PATH." >&2
    echo "  Add this to your shell profile (~/.bashrc) and open a new terminal:" >&2
    echo '  export PATH="$HOME/.local/bin:$PATH"' >&2
    exit 1
fi

echo "==> pipenv version: $(pipenv --version)"

# 3. Make sure the Pipfile is actually here
if [ ! -f "Pipfile" ]; then
    echo "ERROR: No Pipfile found in $REPO_DIR." >&2
    exit 1
fi

# 4. Force an in-project virtual environment at ./.venv
#    (mirrors PDF step 4: pipenv uses ./.venv automatically once that
#    folder exists; PIPENV_VENV_IN_PROJECT makes this explicit/robust)
mkdir -p .venv
export PIPENV_VENV_IN_PROJECT=1

# 5. Install the environment (PDF step 9)
echo "==> Running pipenv install (this can take a while - torch is a large download)..."
pipenv install

echo
echo "==> Done. Virtual environment created at: $REPO_DIR/.venv"
echo
cat <<'EOF'
Next steps (manual, as in the PDF):
  1. Open VSCodium, open this project folder.
  2. Install the "Python" and "Jupyter" extensions if missing (confirm
     "Trust and install").
  3. Open a notebook -> "Select Kernel" -> "Python Environments" -> ".venv"
     (restart VSCodium if it isn't listed yet).
  4. "Run All" to execute the notebook.

To use the environment from a plain shell instead:
  pipenv shell

Troubleshooting (from the PDF):
  If .venv ended up empty or broken, reset it with:
    pipenv --rm
    rm -rf .venv && mkdir .venv
    pipenv install
EOF
