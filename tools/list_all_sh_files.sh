#!/usr/bin/env bash
# ANDRAX 2.0 — List all .sh files recursively

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find "$ROOT" -type f -name '*.sh' | sort
