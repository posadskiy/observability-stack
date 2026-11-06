#!/usr/bin/env bash
# Syntax-check config/alloy/config.alloy with `alloy fmt` (no cluster needed).
# Requires Docker. Catches parse errors only, not wrong component wiring.
#
#   ./scripts/validate-config.sh
#   ALLOY_IMAGE_VERSION=v1.15.0 ./scripts/validate-config.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="grafana/alloy:${ALLOY_IMAGE_VERSION:-v1.15.0}"

command -v docker &>/dev/null || { echo "ERROR: docker not found"; exit 1; }
docker run --rm -v "$ROOT/config/alloy:/cfg:ro" "$IMAGE" fmt /cfg/config.alloy >/dev/null
echo "OK: config/alloy/config.alloy parses ($IMAGE)"
