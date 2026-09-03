#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${ROOT}/app"
VENV_DIR="${ROOT}/.venv"

if [[ ! -f "${APP_DIR}/token_extractor.py" ]]; then
  echo "Not installed. Run ./install.sh first." >&2
  exit 1
fi

exec "${VENV_DIR}/bin/python" "${APP_DIR}/token_extractor.py" "$@"
