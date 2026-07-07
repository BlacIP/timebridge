#!/usr/bin/env bash
# <xbar.title>Provo ⇄ Lagos Time</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>TimeBridge</xbar.author>
# <xbar.desc>Shows Provo, Utah Mountain Time and Nigerian time side by side in the menu bar, with a meeting-hours quick reference in the dropdown. Handles MST/MDT automatically.</xbar.desc>
# <xbar.dependencies>bash</xbar.dependencies>
#
# Works with SwiftBar (https://swiftbar.app) and xbar (https://xbarapp.com).
# The ".1m" in the filename means it refreshes every minute.

set -euo pipefail

# Any IANA time zones work here (run `ls /usr/share/zoneinfo` to browse).
FROM_TZ="America/Denver"
TO_TZ="Africa/Lagos"
FROM_ICON="🏔"
TO_ICON="🇳🇬"

# Set this to your deployed TimeBridge URL to get an "Open converter" link.
APP_URL=""

# City labels derived from the zone ids ("America/Denver" → "Denver").
FROM_LABEL="Provo"
TO_LABEL="Lagos"

now=$(date +%s)

from_menubar=$(TZ=$FROM_TZ date -r "$now" +"%-I:%M%p" | tr '[:upper:]' '[:lower:]')
to_menubar=$(TZ=$TO_TZ date -r "$now" +"%-I:%M%p" | tr '[:upper:]' '[:lower:]')

# --- menu bar line ---
echo "$FROM_ICON $from_menubar · $TO_ICON $to_menubar"
echo "---"

# --- dropdown: full detail ---
from_full=$(TZ=$FROM_TZ date -r "$now" +"%a, %b %-d · %-I:%M %p %Z")
to_full=$(TZ=$TO_TZ date -r "$now" +"%a, %b %-d · %-I:%M %p %Z")
echo "$FROM_LABEL — $from_full | font=Menlo"
echo "$TO_LABEL — $to_full | font=Menlo"
echo "---"

# --- offset (computed, so MST/MDT is always right) ---
offset_str () { # +0100 → signed minutes (handles :30/:45 zones too)
  local z=$1 sign hh mm
  sign=${z:0:1}; hh=${z:1:2}; mm=${z:3:2}
  local total=$((10#$hh * 60 + 10#$mm))
  [ "$sign" = "-" ] && total=$((-total))
  echo "$total"
}
from_off=$(offset_str "$(TZ=$FROM_TZ date -r "$now" +%z)")
to_off=$(offset_str "$(TZ=$TO_TZ date -r "$now" +%z)")
diff_min=$((to_off - from_off))
diff_h=$((diff_min / 60)); diff_m=$(( (diff_min < 0 ? -diff_min : diff_min) % 60 ))
diff_lbl="${diff_h#-}h"; [ "$diff_m" -ne 0 ] && diff_lbl="${diff_lbl} ${diff_m}m"
if [ "$diff_min" -gt 0 ]; then rel="ahead of"; elif [ "$diff_min" -lt 0 ]; then rel="behind"; else rel="level with"; fi
echo "$TO_LABEL is $diff_lbl $rel $FROM_LABEL | color=#999999"
echo "---"

# --- quick reference: FROM-zone business hours today ---
echo "Meeting quick reference (today)"
from_today=$(TZ=$FROM_TZ date -r "$now" +%Y-%m-%d)
for h in 8 9 10 11 12 13 14 15 16 17; do
  epoch=$(TZ=$FROM_TZ date -j -f "%Y-%m-%d %H:%M:%S" "$from_today $h:00:00" +%s)
  from_lbl=$(TZ=$FROM_TZ date -r "$epoch" +"%-I:%M %p")
  to_lbl=$(TZ=$TO_TZ date -r "$epoch" +"%-I:%M %p")
  to_day=$(TZ=$TO_TZ date -r "$epoch" +%Y-%m-%d)
  marker=""
  [ "$to_day" != "$from_today" ] && marker=" (+1d)"
  printf -- "--%8s  →  %s%s | font=Menlo\n" "$from_lbl" "$to_lbl" "$marker"
done
echo "---"

if [ -n "$APP_URL" ]; then
  echo "Open converter | href=$APP_URL"
fi
echo "Refresh | refresh=true"
