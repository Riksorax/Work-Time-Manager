#!/usr/bin/env python3
"""Liest den heutigen lokalen Arbeitseintrag aus FlutterSharedPreferences.xml (Debug-Build, run-as).

Aufruf: entry.py <prefs.xml> <yyyy> <MM> <d>  ->  gibt `start=<0|1> end=<0|1> breaks=<n> open_break=<0|1>` aus.
"""
import json
import sys
import xml.etree.ElementTree as ET

path, year, month, day = sys.argv[1], sys.argv[2], sys.argv[3], str(int(sys.argv[4]))
try:
    root = ET.parse(path).getroot()
except ET.ParseError:
    # Die Datei wird gerade neu geschrieben; der Aufrufer versucht es erneut.
    print("unreadable")
    sys.exit(0)
key = f"flutter.local_work_entries_{year}_{month}"
raw = next((e.text for e in root.iter("string") if e.get("name") == key), None)
entry = {}
if raw:
    entry = json.loads(raw).get("days", {}).get(day) or {}
breaks = entry.get("breaks") or []
open_break = any(b.get("end") in (None, "") for b in breaks)
print(
    f"start={int(bool(entry.get('workStart')))} end={int(bool(entry.get('workEnd')))} "
    f"breaks={len(breaks)} open_break={int(open_break)}"
)
