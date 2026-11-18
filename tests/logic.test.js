const test = require("node:test");
const assert = require("node:assert/strict");
const L = require("../package/contents/code/logic.js");

const FULL =
  "ts_ns=1000000000\ncpu_energy_uj=5000000\ncpu_energy_max_uj=65532610987\n" +
  "cpu_temp_mc=62125\ngpu_power_uw=120000000\ngpu_temp_mc=70000\n";

function reading(tsNs, energy, max = 65532610987) {
  return { tsNs, cpuEnergyUj: energy, cpuEnergyMaxUj: max, cpuTempMc: null,
           gpuPowerUw: null, gpuTempMc: null, cpuNoPerm: false };
}

test("parseReading liest alle Felder", () => {
  assert.deepEqual(L.parseReading(FULL), {
    tsNs: 1000000000, cpuEnergyUj: 5000000, cpuEnergyMaxUj: 65532610987,
    cpuTempMc: 62125, gpuPowerUw: 120000000, gpuTempMc: 70000, cpuNoPerm: false,
  });
});

test("parseReading: noperm und leere Werte", () => {
  const r = L.parseReading("cpu_energy_uj=noperm\ngpu_power_uw=\n");
  assert.equal(r.cpuNoPerm, true);
  assert.equal(r.cpuEnergyUj, null);
  assert.equal(r.gpuPowerUw, null);
  assert.equal(r.cpuTempMc, null);
});

test("cpuWatts: 45 J in 1 s ergibt 45 W", () => {
  assert.equal(L.cpuWatts(reading(1e9, 5e6), reading(2e9, 5e6 + 45e6)), 45);
});

test("cpuWatts: Überlauf des Zählers", () => {
  assert.equal(L.cpuWatts(reading(1e9, 65532000000), reading(2e9, 44389013)), 45);
});

test("cpuWatts: fehlende Daten oder dt <= 0 ergeben null", () => {
  assert.equal(L.cpuWatts(null, reading(2e9, 5e6)), null);
  assert.equal(L.cpuWatts(reading(1e9, null), reading(2e9, 5e6)), null);
  assert.equal(L.cpuWatts(reading(1e9, 5e6), reading(1e9, 6e6)), null);
  assert.equal(L.cpuWatts(reading(1e9, 9e6, null), reading(2e9, 5e6, null)), null);
});

test("cpuWatts: Suspend (dt > 10 s) oder > 1000 W ergeben null", () => {
  assert.equal(L.cpuWatts(reading(1e9, 5e6), reading(31e9, 5e6 + 30 * 45e6)), null);
  assert.equal(L.cpuWatts(reading(1e9, 5e6), reading(2e9, 5e6 + 1500e6)), null);
});

test("Einheiten umrechnen", () => {
  assert.equal(L.toWatts(120000000), 120);
  assert.equal(L.toCelsius(62125), 62.125);
  assert.equal(L.toWatts(null), null);
  assert.equal(L.toCelsius(null), null);
});

test("pushSample und peak", () => {
  const orig = [1, 2, 3];
  assert.deepEqual(L.pushSample(orig, 4, 3), [2, 3, 4]);
  assert.deepEqual(orig, [1, 2, 3]);
  assert.equal(L.peak([1, null, 7, 3]), 7);
  assert.equal(L.peak([null]), null);
});

test("panelText mit Werten", () => {
  assert.equal(L.panelText({ cpuW: 45.4, cpuC: 62.1, gpuW: 120, gpuC: 70 }),
    "🖥️ ⚡45 W 🌡️62° │ 🎮 ⚡120 W 🌡️70°");
});

test("panelText ohne Werte zeigt –", () => {
  assert.equal(L.panelText({ cpuW: null, cpuC: null, gpuW: null, gpuC: null }),
    "🖥️ ⚡– 🌡️– │ 🎮 ⚡– 🌡️–");
});

test("panelLines zweizeilig", () => {
  assert.deepEqual(L.panelLines({ cpuW: 45, cpuC: 62, gpuW: 120, gpuC: 70 }),
    ["🖥️ ⚡45 W 🌡️62°", "🎮 ⚡120 W 🌡️70°"]);
});

test("EMOJI zentral definiert", () => {
  assert.deepEqual(L.EMOJI, { cpu: "🖥️", gpu: "🎮", power: "⚡", temp: "🌡️" });
});

test("formatTempLong für das Popup", () => {
  assert.equal(L.formatTempLong(62.4), "62 °C");
  assert.equal(L.formatTempLong(null), "–");
});

test("Fix: Intervall 10 s mit Jitter ergibt trotzdem CPU-Watt", () => {
  const w = L.cpuWatts(reading(0, 5e6), reading(10.2e9, 5e6 + 10.2 * 45e6), L.maxDtFor(10));
  assert.ok(Math.abs(w - 45) < 1e-9);
  assert.equal(L.maxDtFor(1), 10e9);
  assert.equal(L.maxDtFor(10), 30e9);
  assert.equal(L.cpuWatts(reading(0, 5e6), reading(60e9, 5e6 + 60 * 45e6), L.maxDtFor(10)), null);
});

test("Fix: Befehl mit timeout, damit ein hängendes Skript nicht alles blockiert", () => {
  assert.equal(L.buildCommand("/a/b/read.sh"), "timeout 3 sh '/a/b/read.sh'");
});

test("Fix: Hinweise bei fehlendem Leserecht oder Sensor", () => {
  const ok = L.parseReading("ts_ns=1\ncpu_energy_uj=5\ncpu_energy_max_uj=9\ncpu_temp_mc=1\ngpu_power_uw=1\ngpu_temp_mc=1\n");
  assert.deepEqual(L.hints(ok), []);
  assert.deepEqual(L.hints(L.parseReading("cpu_energy_uj=noperm\ncpu_temp_mc=1\ngpu_power_uw=1\n")),
    ["CPU-Watt: kein Leserecht – einmalig sudo ./install-permissions.sh ausführen"]);
  assert.deepEqual(L.hints(L.parseReading("")), [
    "CPU-Watt: kein RAPL-Zähler gefunden",
    "CPU-Temperatur: kein Sensor gefunden (k10temp/zenpower)",
    "GPU: kein amdgpu-Sensor gefunden",
  ]);
});
