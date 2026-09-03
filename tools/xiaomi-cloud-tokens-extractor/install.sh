#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${ROOT}/app"
VENV_DIR="${ROOT}/.venv"
RELEASE_URL="https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor/releases/latest/download/token_extractor.zip"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not found." >&2
  exit 1
fi

TMP_ZIP="$(mktemp "${TMPDIR:-/tmp}/token_extractor.XXXXXX.zip")"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/token_extractor.XXXXXX")"
cleanup() {
  rm -f "${TMP_ZIP}"
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "Downloading Xiaomi Cloud Tokens Extractor..."
curl --silent --fail --show-error --location --output "${TMP_ZIP}" "${RELEASE_URL}"

echo "Extracting..."
unzip -q "${TMP_ZIP}" -d "${TMP_DIR}"

rm -rf "${APP_DIR}"
mv "${TMP_DIR}/token_extractor" "${APP_DIR}"

echo "Creating virtual environment..."
python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/pip" install --upgrade pip
"${VENV_DIR}/bin/pip" install -r "${APP_DIR}/requirements.txt"

echo "Installed to ${APP_DIR}"
echo "Run: ${ROOT}/run.sh"
