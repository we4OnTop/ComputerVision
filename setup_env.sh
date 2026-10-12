#!/usr/bin/env bash
#
# setup_env.sh
#
# One-shot "start of lab session" script, following
# "Python Setup in AI Perception Lab 2/401" (Muntzinger/Staub):
#   1. sets up the pipenv virtual environment (PDF steps 2-9)
#   2. verifies every package actually imports (checks everything downloaded)
#   3. points VSCodium at the .venv interpreter and launches it in this
#      folder (replaces the manual clicking in PDF steps 10-16)
#
# Run this from inside the cloned repo (it acts as your "PythonProjects"
# folder - no need to create a separate one, the Pipfile already lives here).
#
# NOTE on VSCodium extensions: vanilla VSCodium installs from
# open-vsx.org, not the Microsoft Marketplace. If this machine's
# VSCodium hasn't been configured to use the Microsoft Marketplace (some
# lab installs are), `codium --install-extension ms-python.python` /
# `ms-toolsai.jupyter` may fail or be unavailable. That failure is
# treated as non-fatal below - install them by hand from the Extensions
# view if so (PDF step 13).

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

# 5. Install the environment (PDF step 9). Safe to re-run every session:
#    pipenv only (re)installs what's missing/out of sync with Pipfile.lock.
echo "==> Running pipenv install (first run can take a while - torch is a large download)..."
pipenv install

VENV_PYTHON="$REPO_DIR/.venv/bin/python"
if [ ! -x "$VENV_PYTHON" ]; then
    echo "ERROR: pipenv install finished but $VENV_PYTHON does not exist." >&2
    exit 1
fi

# 6. Verify every package actually downloaded and imports correctly
echo "==> Verifying installed packages..."
set +e
if ! "$VENV_PYTHON" -m jupyter --version >/dev/null 2>&1; then
    echo "WARNING: 'jupyter --version' failed - Jupyter may not be installed correctly." >&2
fi
"$VENV_PYTHON" - <<'PY'
import importlib

# pip distribution name -> importable module name
checks = {
    "numpy": "numpy",
    "matplotlib": "matplotlib",
    "torch": "torch",
    "torchvision": "torchvision",
    "torchinfo": "torchinfo",
    "opencv-python": "cv2",
    "scipy": "scipy",
    "scikit-learn": "sklearn",
    "seaborn": "seaborn",
    "bokeh": "bokeh",
    "pandas": "pandas",
    "albumentations": "albumentations",
    "datasets": "datasets",
    "accelerate": "accelerate",
    "segment-anything": "segment_anything",
    "diffusers": "diffusers",
    "ultralytics": "ultralytics",
    "onnxscript": "onnxscript",
    "moviepy": "moviepy",
    "jinja2": "jinja2",
    "pydantic": "pydantic",
    "openai": "openai",
    "tiktoken": "tiktoken",
    "tavily": "tavily",
    "chromadb": "chromadb",
    "pdfplumber": "pdfplumber",
    "pillow": "PIL",
    "transformers": "transformers",
    "requests": "requests",
}

# Checked best-effort only: uncommon packages whose import name isn't
# certain, so a wrong guess here must not fail the whole script.
optional_checks = {
    "torch-utils": "torch_utils",
}

failed = []
for pip_name, module_name in checks.items():
    try:
        importlib.import_module(module_name)
    except Exception as e:
        failed.append((pip_name, module_name, str(e)))

print(f"{len(checks) - len(failed)}/{len(checks)} packages import OK")
if failed:
    print("\nFAILED imports:")
    for pip_name, module_name, err in failed:
        print(f"  - {pip_name} (import {module_name}): {err}")

for pip_name, module_name in optional_checks.items():
    try:
        importlib.import_module(module_name)
        print(f"{pip_name}: import {module_name} OK")
    except Exception as e:
        print(f"{pip_name}: could not verify (tried 'import {module_name}': {e}) - not treated as a failure, check manually with 'pipenv run pip show {pip_name}'")

try:
    import torch
    print(f"\ntorch {torch.__version__}, CUDA available: {torch.cuda.is_available()}")
except Exception as e:
    print(f"\nCould not check torch/CUDA: {e}")

raise SystemExit(1 if failed else 0)
PY
VERIFY_STATUS=$?
set -e

if [ "$VERIFY_STATUS" -ne 0 ]; then
    echo
    echo "ERROR: Some packages failed to import - the environment is incomplete." >&2
    echo "  Check your network connection and re-run this script. If it keeps" >&2
    echo "  failing, reset the environment (see Troubleshooting below)." >&2
    exit 1
fi

echo
echo "==> Environment OK. Virtual environment at: $REPO_DIR/.venv"

# 7. VSCodium: point it at .venv and launch it in this folder
if ! command -v codium >/dev/null 2>&1; then
    echo
    echo "WARNING: 'codium' not found on PATH - VSCodium should already be" >&2
    echo "  installed on lab PCs (PDF). Skipping VSCodium setup/launch." >&2
else
    echo "==> Configuring VSCodium workspace settings..."
    mkdir -p .vscode

    cat > .vscode/settings.json <<EOF
{
    "python.defaultInterpreterPath": "${VENV_PYTHON}",
    "python.terminal.activateEnvironment": true
}
EOF

    cat > .vscode/extensions.json <<'EOF'
{
    "recommendations": [
        "ms-python.python",
        "ms-toolsai.jupyter"
    ]
}
EOF

    echo "==> Ensuring Python/Jupyter extensions are installed..."
    # Non-fatal: vanilla VSCodium uses open-vsx.org, where these may be
    # unavailable depending on how this machine's VSCodium was set up.
    codium --install-extension ms-python.python >/dev/null 2>&1 \
        || echo "  (could not install ms-python.python automatically - install it by hand if missing)"
    codium --install-extension ms-toolsai.jupyter >/dev/null 2>&1 \
        || echo "  (could not install ms-toolsai.jupyter automatically - install it by hand if missing)"

    echo "==> Launching VSCodium in $REPO_DIR ..."
    nohup codium "$REPO_DIR" >/dev/null 2>&1 &
    disown || true

    cat <<'EOF'

VSCodium is launching with .venv pre-selected as the default interpreter.
On the very first notebook you open, Jupyter may still show a one-time
"Select Kernel" prompt recommending .venv - accept it; after that it's
remembered for the rest of the session. If it ever isn't picked up:
  Select Kernel -> Python Environments -> .venv
EOF
fi

cat <<'EOF'

To use the environment from a plain shell instead of VSCodium:
  pipenv shell

Troubleshooting (from the PDF):
  If .venv ended up empty or broken, reset it with:
    pipenv --rm
    rm -rf .venv && mkdir .venv
    pipenv install
EOF
