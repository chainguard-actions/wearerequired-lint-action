#!/bin/sh
# Fake flake8: logs each invocation (cwd|args) and emits canned output.
# Mode is read from /tmp/flake8-mode ("fail" => report a violation).
echo "$PWD|$*" >> /tmp/flake8-calls.log
case "$1" in
  --version)
    echo "7.0.0 (fake)"
    exit 0
    ;;
esac
mode="$(cat /tmp/flake8-mode 2>/dev/null || echo pass)"
if [ "$mode" = "fail" ]; then
  echo "./sample.py:1:1: F401 'os' imported but unused"
  echo "./sample.py:3:80: E501 line too long (95 > 79 characters)"
  exit 1
fi
exit 0
