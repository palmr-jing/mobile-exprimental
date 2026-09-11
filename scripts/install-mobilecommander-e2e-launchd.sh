#!/bin/bash
# install-mobilecommander-e2e-launchd.sh — install the 3x-daily MobileCommander
# iOS E2E LaunchAgent.
#
# Run this ON palmr-m24. It writes
# ~/Library/LaunchAgents/com.palmr.mobilecommander-e2e.plist with three
# StartCalendarInterval entries (09:00, 15:00, 21:00 LOCAL time) and loads it.
# Offset 30 min from palmr-coach-ios (08:30/14:30/20:30) so the two iOS E2E runs
# don't both hammer Drive at the same minute.
#
# IMPORTANT — timezone: launchd's StartCalendarInterval fires on the machine's
# LOCAL time. m24 must be set to America/New_York for ET.
# Verify with `sudo systemsetup -gettimezone` or `date +%Z`.
#
# Usage: ./install-mobilecommander-e2e-launchd.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LABEL="com.palmr.mobilecommander-e2e"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$REPO_DIR/logs/launchd-e2e.log"

mkdir -p "$REPO_DIR/logs"
mkdir -p "$HOME/Library/LaunchAgents"

# Reload cleanly if already installed.
if launchctl list 2>/dev/null | grep -q "$LABEL"; then
  echo "Unloading existing $LABEL..."
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null \
    || launchctl unload -w "$PLIST" 2>/dev/null \
    || true
fi

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT_DIR/run-ios-e2e-and-publish.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$REPO_DIR</string>
  <!-- Fire at 09:00, 15:00, 21:00 LOCAL time, 7 days a week.
       Offset 30 min from palmr-coach-ios to avoid Drive contention. -->
  <key>StartCalendarInterval</key>
  <array>
    <dict>
      <key>Hour</key><integer>9</integer>
      <key>Minute</key><integer>0</integer>
    </dict>
    <dict>
      <key>Hour</key><integer>15</integer>
      <key>Minute</key><integer>0</integer>
    </dict>
    <dict>
      <key>Hour</key><integer>21</integer>
      <key>Minute</key><integer>0</integer>
    </dict>
  </array>
  <!-- Scheduled job, not a daemon: do not run on load. -->
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$LOG</string>
  <key>StandardErrorPath</key>
  <string>$LOG</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/opt/openjdk/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>JAVA_HOME</key>
    <string>/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>
</dict>
</plist>
EOF

echo "Wrote $PLIST"

if ! launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
  launchctl load -w "$PLIST"
fi
echo "Loaded $LABEL"
sleep 2

echo "---"
launchctl list | grep "$LABEL" || echo "Not running!"
echo "---"
echo "Schedule: 09:00 / 15:00 / 21:00 local time (host TZ must be America/New_York for ET)"
echo "launchd log: $LOG"
echo "Run log:     $REPO_DIR/logs/e2e-runs.log"
echo
echo "Manual trigger: launchctl start $LABEL"
