#!/bin/sh
# Nimmt die Freigabe aus install-permissions.sh zurück.
set -eu

CONF="${DESTDIR:-}/etc/tmpfiles.d/plasma-power-widget.conf"
RAPL=/sys/class/powercap/intel-rapl:0/energy_uj

if [ -z "${DESTDIR:-}" ] && [ "$(id -u)" -ne 0 ]; then
  echo "Bitte mit sudo ausführen: sudo $0" >&2
  exit 1
fi

rm -f "$CONF"
echo "Entfernt: $CONF"

if [ "${SKIP_APPLY:-0}" != 1 ] && [ -e "$RAPL" ]; then
  chmod 0400 "$RAPL"
  echo "Leserecht zurückgesetzt."
fi
