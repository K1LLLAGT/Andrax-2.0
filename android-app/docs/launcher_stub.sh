#!/usr/bin/env bash
# ANDRAX 2.0 — Android-side launcher stub
# This is what the app execs via Runtime.getRuntime().exec(...)
# It forwards to Termux ANDRAX IPC contract.

TERMUX_HOME="/data/data/com.termux/files/home"
ANDRAX_HOME="$TERMUX_HOME/ANDRAX/ANDRAX-2.0"
IPC="$ANDRAX_HOME/launcher/andrax-ipc-contract.sh"

exec "$IPC" "$@"
