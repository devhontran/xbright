#!/bin/sh
set -eu
cd "$(dirname "$0")"

[ -f .ship-host ] && XBRIGHT_HOST="${XBRIGHT_HOST:-$(cat .ship-host)}"
HOST="${XBRIGHT_HOST:?set XBRIGHT_HOST=user@host or write it to .ship-host}"

./build.sh
COPYFILE_DISABLE=1 tar -C build -cf - XBright.app | ssh -o BatchMode=yes "$HOST" '
set -eu
LABEL=dev.hontran.xbright
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
while launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; do sleep 0.2; done

rm -rf /Applications/XBright.app
tar -C /Applications -xf -

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Applications/XBright.app/Contents/MacOS/XBright</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>ProcessType</key>
	<string>Interactive</string>
</dict>
</plist>
EOF

launchctl bootstrap "$DOMAIN" "$PLIST"
sleep 1
launchctl print "$DOMAIN/$LABEL" | grep -E "state =|pid ="
/Applications/XBright.app/Contents/MacOS/XBright get
'
