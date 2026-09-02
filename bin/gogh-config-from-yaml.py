#!/usr/bin/env python3
"""Reads a YAML config on stdin, writes the equivalent JSON to stdout.
Exits non-zero (with a message on stderr) if the YAML is invalid or its
root isn't a mapping, so the caller never overwrites config.json with junk.
"""
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
        data = yaml.safe_load(raw)
    except yaml.YAMLError as e:
        print(f"Invalid YAML: {e}", file=sys.stderr)
        sys.exit(1)

    if data is None:
        data = {}
    if not isinstance(data, dict):
        print("YAML root must be a mapping (key: value), not a list or scalar", file=sys.stderr)
        sys.exit(1)

    json.dump(data, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
