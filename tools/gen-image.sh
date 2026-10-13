#!/usr/bin/env bash
set -euo pipefail

# gen-image.sh — generate an image via Google Antigravity CLI (agy) + Gemini.
#
# Usage:
#   gen-image.sh "<prompt>" --output <absolute-path> [--ratio 16:9|4:3|1:1] [--name <slug>]
#
# Requirements:
#   - `agy` on PATH, or set AGY_BIN to the binary path.
#   - agy authenticated (signed-in account), or GEMINI_API_KEY + modelProvider=gemini.
#
# The helper encodes the headless agy contract:
#   * --dangerously-skip-permissions  (agy self-denies tool use headless otherwise)
#   * --add-dir <workspace>           (agy ignores the shell working directory)
#   * absolute output paths in the prompt
#   * ask agy to end with IMAGE_PATH: <path>, then move the file there.

AGY="${AGY_BIN:-agy}"
RATIO="1:1"
NAME=""
OUTPUT=""
PROMPT=""

usage() {
  echo "usage: $0 \"<prompt>\" --output <abs-path> [--ratio 16:9|4:3|1:1] [--name <slug>]" >&2
  exit 2
}

if [ $# -lt 1 ]; then usage; fi
PROMPT="$1"; shift

while [ $# -gt 0 ]; do
  case "$1" in
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --ratio)  RATIO="${2:-1:1}"; shift 2 ;;
    --name)   NAME="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$OUTPUT" ] || usage

# Normalize output to an absolute path.
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"
WORKSPACE="$(cd "$(dirname "$OUTPUT")" && pwd)"
mkdir -p "$WORKSPACE"

# agy must write somewhere we can find; request a deterministic absolute path.
TMP_TARGET="${OUTPUT}"

# Compose the full prompt that agy sees.
FULL_PROMPT="${PROMPT}
RATIO: ${RATIO}
Generate the image at this absolute path: ${TMP_TARGET}
End your reply with a single line exactly:
IMAGE_PATH: ${TMP_TARGET}"

echo "==> Running agy (ratio=${RATIO}, output=${OUTPUT})" >&2

RESP="$("$AGY" -p "$FULL_PROMPT" \
  --dangerously-skip-permissions \
  --add-dir "$WORKSPACE" 2>&1 || true)"

echo "$RESP" >&2

# 1) Preferred: the IMAGE_PATH contract.
IMG_PATH="$(printf '%s\n' "$RESP" | grep -o 'IMAGE_PATH:.*' | head -n1 | sed 's/^IMAGE_PATH:[[:space:]]*//')"

# 2) Fallback: any absolute image path printed.
if [ -z "$IMG_PATH" ]; then
  IMG_PATH="$(printf '%s\n' "$RESP" | grep -oE '/[^ ]+\.(png|jpg|jpeg|webp)' | head -n1 || true)"
fi

if [ -n "$IMG_PATH" ] && [ -f "$IMG_PATH" ]; then
  cp "$IMG_PATH" "$OUTPUT"
  echo "IMAGE_PATH: $OUTPUT"
else
  echo "WARN: could not locate the generated file (searched IMAGE_PATH and the reply)." >&2
  echo "WARN: agy may have written it under ~/.gemini/antigravity-cli/. Check the log above." >&2
  exit 1
fi
