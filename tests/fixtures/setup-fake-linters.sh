#!/usr/bin/env bash
# Sets up deterministic fake linters (flake8, black) and a `python` shim on PATH,
# and prepares a workflow_dispatch event payload containing the fields the
# action reads (event.ref, event.repository.full_name/clone_url).
#
# Usage: bash tests/fixtures/setup-fake-linters.sh <flake8-mode>
#   flake8-mode: "clean" (exit 0, no output) or "errors" (prints violations, exit 1)
set -euo pipefail

MODE="${1:-clean}"
FAKE_DIR=/tmp/fake-lint
BIN_DIR="$FAKE_DIR/bin"
rm -rf "$FAKE_DIR"
mkdir -p "$BIN_DIR"
echo "$MODE" > "$FAKE_DIR/flake8-mode"
: > "$FAKE_DIR/flake8.log"
: > "$FAKE_DIR/black.log"

# python shim (the action checks `command -v python` before running flake8/black)
if ! command -v python >/dev/null 2>&1; then
  cat > "$BIN_DIR/python" <<'EOF'
#!/bin/sh
if command -v python3 >/dev/null 2>&1; then exec python3 "$@"; fi
echo "Python 3.x (fake shim)"
EOF
  chmod +x "$BIN_DIR/python"
fi

cat > "$BIN_DIR/flake8" <<'EOF'
#!/bin/sh
echo "cwd=$(pwd) args=$*" >> /tmp/fake-lint/flake8.log
if [ "$1" = "--version" ]; then
  echo "7.0.0 (fake flake8)"
  exit 0
fi
mode="$(cat /tmp/fake-lint/flake8-mode 2>/dev/null || echo clean)"
if [ "$mode" = "errors" ]; then
  echo "./bad.py:1:1: F401 'os' imported but unused"
  echo "./bad.py:3:80: E501 line too long (100 > 79 characters)"
  exit 1
fi
exit 0
EOF
chmod +x "$BIN_DIR/flake8"

cat > "$BIN_DIR/black" <<'EOF'
#!/bin/sh
echo "cwd=$(pwd) args=$*" >> /tmp/fake-lint/black.log
if [ "$1" = "--version" ]; then
  echo "black, 24.0.0 (fake)"
  exit 0
fi
case " $* " in
  *" --check "*)
    echo "would reformat (fake)" >&2
    exit 1
    ;;
esac
# Fix mode: "format" every .py file in the current directory
for f in *.py; do
  [ -f "$f" ] || continue
  sed -i 's/^x=1$/x = 1/' "$f"
done
echo "reformatted (fake)" >&2
exit 0
EOF
chmod +x "$BIN_DIR/black"

echo "$BIN_DIR" >> "$GITHUB_PATH"

# Build an event payload with the fields the action needs for workflow_dispatch.
node -e '
const fs = require("fs");
const src = process.env.GITHUB_EVENT_PATH;
let e = {};
try { e = JSON.parse(fs.readFileSync(src, "utf8") || "{}") || {}; } catch (err) { e = {}; }
if (typeof e.ref !== "string" || !e.ref.startsWith("refs/heads/")) e.ref = "refs/heads/act-harness";
e.repository = e.repository || {};
const repo = process.env.GITHUB_REPOSITORY || "actionchain-harness/repo";
e.repository.full_name = e.repository.full_name || repo;
e.repository.clone_url = e.repository.clone_url || ("https://github.com/" + repo + ".git");
const out = JSON.stringify(e);
fs.writeFileSync("/tmp/fake-lint/event.json", out);
try { fs.writeFileSync(src, out); } catch (err) { console.log("could not patch original event file: " + err.message); }
console.log("event payload: " + out);
'
