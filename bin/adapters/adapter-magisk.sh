#!/usr/bin/env bash
CMD="$1"
echo "[Magisk Adapter] $CMD"
su -c "$CMD"
