#!/bin/sh
set -eu

app_dir="${HOME}/Applications/AIStupidLevelWatcher.app"
agent_label="com.whyy9527.aistupidlevel.menu-bar-watcher"
agent_plist="${HOME}/Library/LaunchAgents/${agent_label}.plist"
uid_value=$(id -u)

launchctl bootout "gui/${uid_value}/${agent_label}" 2>/dev/null || true
rm -f "$agent_plist"
rm -rf "$app_dir"

printf 'Removed LaunchAgent: %s\n' "$agent_label"
printf 'Removed app bundle: %s\n' "$app_dir"
