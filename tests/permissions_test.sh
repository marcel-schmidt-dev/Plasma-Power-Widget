#!/usr/bin/env bash
# Testet install-permissions.sh / uninstall-permissions.sh ohne root (DESTDIR + SKIP_APPLY).
set -u
cd "$(dirname "$0")/.." || exit 1
FAILS=0
fail() { echo "FAIL: $1"; FAILS=$((FAILS+1)); }
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
CONF="$D/etc/tmpfiles.d/plasma-power-widget.conf"
LINE='z /sys/class/powercap/intel-rapl:0/energy_uj 0444 - - -'

DESTDIR=$D SKIP_APPLY=1 sh ./install-permissions.sh >/dev/null || fail "install exit != 0"
[ -f "$CONF" ] || fail "Datei fehlt nach install"
[ "$(cat "$CONF" 2>/dev/null)" = "$LINE" ] || fail "Inhalt falsch: $(cat "$CONF" 2>/dev/null)"

DESTDIR=$D SKIP_APPLY=1 sh ./uninstall-permissions.sh >/dev/null || fail "uninstall exit != 0"
if [ -e "$CONF" ]; then fail "Datei noch da nach uninstall"; fi

if [ "$(id -u)" -ne 0 ]; then
  sh ./install-permissions.sh >/dev/null 2>&1; rc=$?
  [ $rc -eq 1 ] || fail "ohne root und ohne DESTDIR: exit $rc statt 1"
  sh ./uninstall-permissions.sh >/dev/null 2>&1; rc=$?
  [ $rc -eq 1 ] || fail "uninstall ohne root: exit $rc statt 1"
fi

if [ $FAILS -eq 0 ]; then echo OK; else echo "$FAILS Fehler"; exit 1; fi
