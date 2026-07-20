#!/usr/bin/env bash
# ANDRAX 2.0 — Magisk bridge (post-fs-data)
# Standard install location (matches INSTALL.md and the app's ENGINE_PATH):
#   $HOME/ANDRAX-2.0  ==  /data/data/com.termux/files/home/ANDRAX-2.0
ANDRAX_HOME="/data/data/com.termux/files/home/ANDRAX-2.0"
BIN_DIR="$ANDRAX_HOME/bin"

mkdir -p "$BIN_DIR"

# Example privileged tools (adjust paths to your setup)
mount --bind /system/bin/tcpdump "$BIN_DIR/tcpdump" 2>/dev/null
mount --bind /system/xbin/nmap "$BIN_DIR/nmap" 2>/dev/null
