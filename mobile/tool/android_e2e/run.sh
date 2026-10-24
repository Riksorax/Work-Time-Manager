#!/usr/bin/env bash
# Android-Emulator-Test für Timer-Aktionen von außen (#280 Assistant, #485 Hintergrund).
# Läuft in .github/workflows/android-emulator.yml; erwartet einen Emulator mit `adb root`
# (Image `google_apis`) und einen Debug-APK (run-as liest die SharedPreferences).
#
# Aufruf: run.sh <app-debug.apk>
set -euo pipefail

PKG=app.work_time_manager
APK=${1:?Pfad zum Debug-APK}
HERE="$(cd "$(dirname "$0")" && pwd)"
RECEIVER=com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver
FAIL=0

log() { echo "[$(date +%T)] $*"; }

entry() {
  local y m d
  y=$(adb shell date +%Y | tr -d '\r'); m=$(adb shell date +%m | tr -d '\r'); d=$(adb shell date +%d | tr -d '\r')
  adb shell "run-as $PKG cat shared_prefs/FlutterSharedPreferences.xml" > /tmp/prefs.xml 2>/dev/null || echo '<map/>' > /tmp/prefs.xml
  python3 "$HERE/entry.py" /tmp/prefs.xml "$y" "$m" "$d"
}

# expect <Beschreibung> <erwartet> – wartet bis zu 60 s auf den Zustand.
expect() {
  local what=$1 want=$2 got=""
  for _ in $(seq 1 30); do
    got=$(entry)
    if [ "$got" = "$want" ]; then log "OK   $what ($got)"; return 0; fi
    sleep 2
  done
  log "FAIL $what: erwartet '$want', gefunden '$got'"
  FAIL=1
  return 0
}

assistant() { adb shell am start -W -n "$PKG/.MainActivity" -a app.work_time_manager.ASSISTANT_TIMER --es feature "$1" >/dev/null; }

notification_action() {
  adb shell am broadcast -a "$RECEIVER.ACTION_TAPPED" -n "$PKG/$RECEIVER" \
    --es actionId "$1" --ei notificationId 1 --es payload open_dashboard --ez cancelNotification true >/dev/null
}

adb wait-for-device
adb root >/dev/null || true
adb wait-for-device
adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true

log "Installiere APK"
adb install -r -g "$APK"
adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS || true
adb logcat -c

log "Erster Start (registriert den Hintergrund-Handler des Plugins)"
adb shell am start -W -n "$PKG/.MainActivity" >/dev/null
sleep 30
adb shell am force-stop "$PKG"
expect "kein Eintrag nach dem ersten Start" "start=0 end=0 breaks=0 open_break=0"

log "#280: Assistant-Intent bei Kaltstart"
assistant "Arbeitstag starten"
expect "Assistant 'Arbeitstag starten' startet den Timer" "start=1 end=0 breaks=0 open_break=0"

log "#280: Assistant-Intent bei laufender App (onNewIntent)"
assistant "Pause starten"
expect "Assistant 'Pause starten'" "start=1 end=0 breaks=1 open_break=1"
assistant "Pause beenden"
expect "Assistant 'Pause beenden'" "start=1 end=0 breaks=1 open_break=0"

log "#485: Notification-Aktion bei laufender App (Weiterleitung an die App)"
adb shell am start -W -n "$PKG/.MainActivity" >/dev/null
adb shell input keyevent KEYCODE_HOME
sleep 3
notification_action timer_pause
expect "Notification 'Pause' bei laufender App" "start=1 end=0 breaks=2 open_break=1"
notification_action timer_resume
expect "Notification 'Weiter' bei laufender App" "start=1 end=0 breaks=2 open_break=0"

log "#485: Notification-Aktion OHNE laufende App (Hintergrund-Isolate)"
adb shell am force-stop "$PKG"
sleep 2
notification_action timer_pause
expect "Hintergrund: 'Pause starten'" "start=1 end=0 breaks=3 open_break=1"
notification_action timer_resume
expect "Hintergrund: 'Pause beenden'" "start=1 end=0 breaks=3 open_break=0"
notification_action timer_stop
expect "Hintergrund: 'Ausstempeln'" "start=1 end=1 breaks=3 open_break=0"

if adb shell dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity" | grep -q "$PKG"; then
  log "FAIL Die App hat sich bei der Hintergrund-Aktion geöffnet"
  FAIL=1
else
  log "OK   Die App blieb bei der Hintergrund-Aktion geschlossen"
fi

adb logcat -d -s flutter:V AndroidRuntime:E ActionBroadcastReceiver:V > /tmp/logcat.txt || true
tail -n 80 /tmp/logcat.txt || true
if [ "$FAIL" -ne 0 ]; then log "Mindestens ein Schritt ist fehlgeschlagen"; exit 1; fi
log "Alle Schritte bestanden"
