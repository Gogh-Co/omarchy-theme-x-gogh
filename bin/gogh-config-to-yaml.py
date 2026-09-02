#!/usr/bin/env python3
"""Reads config.json (JSON) on stdin, writes the equivalent YAML to stdout."""
import json
import sys

try:
    import yaml
except ImportError:
    print("python-yaml is not installed (pacman -S python-yaml)", file=sys.stderr)
    sys.exit(1)


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        data = {}
    yaml.safe_dump(data, sys.stdout, default_flow_style=False, sort_keys=False, allow_unicode=True)


if __name__ == "__main__":
    main()
