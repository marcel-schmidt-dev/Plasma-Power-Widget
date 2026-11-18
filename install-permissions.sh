#!/bin/sh
# Macht den RAPL-Energiezähler für alle Benutzer lesbar, damit das Widget
# die CPU-Leistung anzeigen kann. Bleibt über Neustarts erhalten (tmpfiles.d).
# Risiko: siehe README (PLATYPUS, CVE-2020-8694).
set -eu

CONF="${DESTDIR:-}/etc/tmpfiles.d/plasma-power-widget.conf"
LINE='z /sys/class/powercap/intel-rapl:0/energy_uj 0444 - - -'

if [ -z "${DESTDIR:-}" ] && [ "$(id -u)" -ne 0 ]; then
  echo "Bitte mit sudo ausführen: sudo $0" >&2
  exit 1
fi

mkdir -p "$(dirname "$CONF")"
printf '%s\n' "$LINE" > "$CONF"
echo "Geschrieben: $CONF"

if [ "${SKIP_APPLY:-0}" != 1 ]; then
  systemd-tmpfiles --create "$CONF"
  echo "Leserecht gesetzt. Das Widget zeigt die CPU-Watt ab dem nächsten Takt."
fi
