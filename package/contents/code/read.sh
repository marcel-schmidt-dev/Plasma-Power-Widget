#!/bin/sh
# Liest Leistung und Temperatur von AMD-CPU und -GPU aus sysfs.
# Aufruf: read.sh [ROOT]   (ROOT nur für Tests, sonst leer = echtes /sys)
# Ausgabe: key=value-Zeilen; fehlende Werte bleiben leer. Exit-Code immer 0.

ROOT=${1:-}
HWMON="$ROOT/sys/class/hwmon"
RAPL="$ROOT/sys/class/powercap/intel-rapl:0"

# Erste Zeile einer Datei, leer wenn nicht vorhanden oder nicht lesbar.
val() {
  [ -r "$1" ] || return 0
  read -r v < "$1" 2>/dev/null && printf '%s' "$v"
}

cpu_energy=""
if [ -e "$RAPL/energy_uj" ]; then
  if [ -r "$RAPL/energy_uj" ]; then cpu_energy=$(val "$RAPL/energy_uj"); else cpu_energy=noperm; fi
fi
cpu_energy_max=$(val "$RAPL/max_energy_range_uj")

cpu_temp=""
gpu_dir=""
gpu_vram=-1
for h in "$HWMON"/hwmon*; do
  [ -d "$h" ] || continue
  case $(val "$h/name") in
    k10temp|zenpower)
      [ -z "$cpu_temp" ] && cpu_temp=$(val "$h/temp1_input")
      ;;
    amdgpu)
      vram=$(val "$h/device/mem_info_vram_total")
      vram=${vram:-0}
      if [ "$vram" -gt "$gpu_vram" ] 2>/dev/null; then gpu_vram=$vram; gpu_dir=$h; fi
      ;;
  esac
done

gpu_power=""
gpu_temp=""
if [ -n "$gpu_dir" ]; then
  gpu_power=$(val "$gpu_dir/power1_average")
  [ -z "$gpu_power" ] && gpu_power=$(val "$gpu_dir/power1_input")
  gpu_temp=$(val "$gpu_dir/temp1_input")
fi

printf 'ts_ns=%s\n' "$(date +%s%N)"
printf 'cpu_energy_uj=%s\n' "$cpu_energy"
printf 'cpu_energy_max_uj=%s\n' "$cpu_energy_max"
printf 'cpu_temp_mc=%s\n' "$cpu_temp"
printf 'gpu_power_uw=%s\n' "$gpu_power"
printf 'gpu_temp_mc=%s\n' "$gpu_temp"
exit 0
