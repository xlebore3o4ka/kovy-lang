#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/site"
exec python3 -m http.server "${PORT:-8765}" --bind "${HOST:-127.0.0.1}"
