#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
app_dir="${HOME}/Applications/AIStupidLevelWatcher.app"
app_binary="${app_dir}/Contents/MacOS/AIStupidLevelWatcher"
agent_label="com.whyy9527.aistupidlevel.menu-bar-watcher"
agent_dir="${HOME}/Library/LaunchAgents"
agent_plist="${agent_dir}/${agent_label}.plist"
log_dir="${HOME}/Library/Logs/AIStupidLevelWatcher"
uid_value=$(id -u)

swift build --package-path "$repo_dir" -c release
bin_dir=$(swift build --package-path "$repo_dir" -c release --show-bin-path)

mkdir -p "${app_dir}/Contents/MacOS" "${app_dir}/Contents/Resources" "$agent_dir" "$log_dir"
cp "$bin_dir/AIStupidLevelWatcher" "$app_binary"
cp "$repo_dir/Resources/Info.plist" "${app_dir}/Contents/Info.plist"
cp "$repo_dir/Resources/AppIcon.icns" "${app_dir}/Contents/Resources/AppIcon.icns"
rm -f "${app_dir}/Contents/Resources/SmartCoreIcon.png"
chmod 755 "$app_binary"
codesign --force --sign - "$app_dir"

sed \
    -e "s|__APP_BINARY__|${app_binary}|g" \
    -e "s|__LOG_DIR__|${log_dir}|g" \
    "$repo_dir/Resources/LaunchAgent.plist.template" > "$agent_plist"
chmod 644 "$agent_plist"

launchctl bootout "gui/${uid_value}/${agent_label}" 2>/dev/null || true
bootstrap_attempt=1
while ! launchctl bootstrap "gui/${uid_value}" "$agent_plist"; do
    if [ "$bootstrap_attempt" -ge 5 ]; then
        printf 'Failed to register LaunchAgent after %s attempts.\n' "$bootstrap_attempt" >&2
        exit 1
    fi
    bootstrap_attempt=$((bootstrap_attempt + 1))
    sleep 1
done
launchctl kickstart -k "gui/${uid_value}/${agent_label}"

printf 'Installed: %s\n' "$app_dir"
printf 'LaunchAgent: %s\n' "$agent_plist"
printf 'Logs: %s\n' "$log_dir"
