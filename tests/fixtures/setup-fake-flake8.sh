#!/usr/bin/env bash
# Usage: setup-fake-flake8.sh <mode>
#   mode = clean   -> fake flake8 reports no problems (exit 0)
#   mode = errors  -> fake flake8 reports one error (exit 1)
#   mode = broken  -> fake flake8 is not runnable (--version fails)
#   mode = none    -> only write the event payload, no fake tools
set -euo pipefail
MODE="${1:-clean}"

# 1. Make sure the event payload contains the fields lint-action parses for
#    workflow_dispatch events (event.ref and event.repository.*).
cat > "$GITHUB_EVENT_PATH" <<EOF
{
  "ref": "refs/heads/act-harness",
  "repository": {
    "full_name": "${GITHUB_REPOSITORY}",
    "clone_url": "https://github.com/${GITHUB_REPOSITORY}.git"
  }
}
EOF
echo "Event payload at $GITHUB_EVENT_PATH:"
cat "$GITHUB_EVENT_PATH"

[ "$MODE" = "none" ] && exit 0

# 2. Fake tools on PATH
BIN=/tmp/fake-lint-bin
rm -rf "$BIN" /tmp/flake8-calls.log
mkdir -p "$BIN"
touch /tmp/flake8-calls.log

cat > "$BIN/python" <<'EOF'
#!/bin/sh
if command -v python3 >/dev/null 2>&1; then exec python3 "$@"; fi
echo "Python 3.0.0 (fake)"
EOF

cat > "$BIN/flake8" <<EOF
#!/bin/sh
MODE="$MODE"
echo "ARGS: \$*" >> /tmp/flake8-calls.log
echo "PWD: \$(pwd)" >> /tmp/flake8-calls.log
echo "FAKE_PREFIX_VAR: \${FAKE_PREFIX_VAR:-}" >> /tmp/flake8-calls.log
case "\$*" in
  *--version*)
    if [ "\$MODE" = "broken" ]; then echo "flake8: broken" >&2; exit 127; fi
    echo "7.0.0 (fake)"; exit 0 ;;
esac
if [ "\$MODE" = "errors" ]; then
  echo "./sample/bad.py:3:1: E302 expected 2 blank lines, found 1"
  exit 1
fi
exit 0
EOF
chmod +x "$BIN/python" "$BIN/flake8"
echo "$BIN" >> "$GITHUB_PATH"
