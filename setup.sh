#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

readonly PYTHON_VERSION="3.14"
readonly PANDOC_VERSION="3.9.0.2"
readonly VENV_DIR="$SCRIPT_DIR/.venv"
readonly PYTHON="$VENV_DIR/bin/python"
readonly PANDOC="$VENV_DIR/bin/pandoc"

python_cmd=""
for candidate in python3.14 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
        detected_version="$($candidate -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
        if [[ "$detected_version" == "$PYTHON_VERSION" ]]; then
            python_cmd="$candidate"
            break
        fi
    fi
done

if [[ -z "$python_cmd" ]]; then
    echo "Python $PYTHON_VERSION is required (python3.14 or python3 on PATH)." >&2
    exit 1
fi

"$python_cmd" -m venv "$VENV_DIR"
"$PYTHON" -m pip install --upgrade pip
"$PYTHON" -m pip install -r "$SCRIPT_DIR/requirements.txt"
#"$PYTHON" -m nltk.downloader -d "$VENV_DIR/nltk_data" punkt_tab

installed_pandoc_version=""
if [[ -x "$PANDOC" ]]; then
    installed_pandoc_version="$("$PANDOC" --version 2>/dev/null | sed -n '1{s/^pandoc //;p;}')" || true
fi

if [[ "$installed_pandoc_version" != "$PANDOC_VERSION" ]]; then
    max_attempts=5
    downloaded=false

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        echo "Installing Pandoc $PANDOC_VERSION (attempt $attempt of $max_attempts)..."
        if "$PYTHON" -c 'import pypandoc, sys; pypandoc.download_pandoc(version=sys.argv[1], targetfolder=sys.argv[2], delete_installer=True)' \
            "$PANDOC_VERSION" "$VENV_DIR/bin"; then
            downloaded=true
            break
        fi

        if (( attempt < max_attempts )); then
            delay_seconds=$((2 ** attempt))
            echo "Pandoc download failed; retrying in ${delay_seconds}s..." >&2
            sleep "$delay_seconds"
        fi
    done

    if [[ "$downloaded" != true ]]; then
        echo "Failed to install Pandoc $PANDOC_VERSION after $max_attempts attempts." >&2
        exit 1
    fi
fi

if [[ ! -x "$PANDOC" ]] || ! "$PANDOC" --version | sed -n '1p' | grep -Fxq "pandoc $PANDOC_VERSION"; then
    echo "Pandoc $PANDOC_VERSION is not available at $PANDOC." >&2
    exit 1
fi

export PLAYWRIGHT_BROWSERS_PATH=0
"$VENV_DIR/bin/rfbrowser" init --with-deps chromium

echo "Linux setup completed successfully."
