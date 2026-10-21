#!/usr/bin/env python3
"""Generate the System Monitor "System" page for the hardware of this PC.

Reads the sensors from ksystemstats (kstatsviewer), the CPU from /proc and /sys and the
filesystems from findmnt, then writes a .page file with four rows: system tiles /
CPU, cores, memory / temperatures, power, fans / GPU, disks, disk space, network.
Whatever is missing is skipped.

Usage: generate-page.py [-o FILE]   (without -o it writes to stdout; the summary goes to stderr)
"""
import argparse
import re
import subprocess
import sys

BLUE, ORANGE, GREEN, RED, PURPLE, TEAL = "61,174,233", "246,116,0", "39,174,96", "218,68,83", "155,89,182", "26,188,156"
YELLOW, GREY, PINK, LIGHT_BLUE, SKY = "253,188,75", "127,140,141", "233,61,164", "142,200,233", "137,220,255"
SPARE = [LIGHT_BLUE, SKY, "150,204,188", "241,196,15", "85,255,255", "61,233,118"]
# Temperatures: one colour per kind; motherboard sensors take BOARD_COLORS in order
TEMP_COLORS = {"CPU": RED, "GPU": PURPLE, "RAM": YELLOW, "NVMe": GREEN, "SATA": TEAL, "NIC": PINK}
BOARD_COLORS = [ORANGE, BLUE, GREY]
# Order of the temperatures: motherboard sensors ("board") are interleaved with the others
TEMP_ORDER = ["CPU", "GPU", "board", "RAM", "NVMe", "SATA", "board", "NIC", "board"]
DISK_COLORS = [(BLUE, ORANGE), (LIGHT_BLUE, YELLOW), (GREEN, PURPLE), (TEAL, RED)]
SPACE_COLORS = [BLUE, ORANGE, GREEN]
FAN_COLORS = [SKY, TEAL, BLUE, PURPLE]
RATE = 1000
DEVICE = re.compile(r"^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|xvd[a-z]+|hd[a-z]+|mmcblk\d+)$")
# lm-sensors chips already covered by cpu/all/... and gpu/gpuN/...
CPU_CHIPS = ("k10temp", "coretemp", "zenpower")
GPU_CHIPS = ("amdgpu", "radeon", "nouveau", "i915", "xe")
# Line charts: settings shared by the whole page
LINE = dict(lineChartSmooth="true", showLegend="true")


def log(*args):
    print(*args, file=sys.stderr)


def run(cmd, timeout=10):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.TimeoutExpired) as e:
        out = getattr(e, "stdout", None)
        return out.decode() if isinstance(out, bytes) else (out or "")


def sensor_list():
    """{id: name} of all the available sensors."""
    sensors = {}
    for line in run(["kstatsviewer", "--list"]).splitlines():
        sid, _, name = line.partition(" ")
        if sid:
            sensors[sid] = name
    return sensors


def sample(ids, seconds=2.5):
    """Last value of each sensor after a few updates (the first one is often 0)."""
    values = {}
    if not ids:
        return values
    for line in run(["timeout", str(seconds), "kstatsviewer", "--remain", *ids], timeout=seconds + 5).splitlines():
        sid, _, value = line.partition(" ")
        try:
            values[sid] = float(value)
        except ValueError:
            values[sid] = value
    return values


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def natural(s):
    """Natural sort key: temp2 before temp10."""
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", s)]


def numbered(items):
    """Numbers repeated labels: RAM, RAM -> RAM 1, RAM 2."""
    labels = [label for _, label in items]
    seen = {}
    out = []
    for sid, label in items:
        if labels.count(label) > 1:
            seen[label] = seen.get(label, 0) + 1
            label = f"{label} {seen[label]}"
        out.append((sid, label))
    return out


class Page:
    def __init__(self):
        self.out = []

    def face(self, n, chart, sensors, title=None, low=(), extra=None):
        """sensors / low: lists of (id, label, colour or None)"""
        out = self.out
        out.append(f"[Face-{n}][Appearance]\nchartFace={chart}\nshowTitle={'true' if title else 'false'}")
        if title:
            out.append(f"title={title}")
        out.append(f"updateRateLimit={RATE}\n")
        allsens = list(sensors) + list(low)
        cols = sorted((s, c) for s, _, c in allsens if c)
        if cols:
            out.append(f"[Face-{n}][SensorColors]")
            out.extend(f"{s}={c}" for s, c in cols)
            out.append("")
        out.append(f"[Face-{n}][SensorLabels]")
        out.extend(f"{s}={l}" for s, l in sorted((s, l) for s, l, _ in allsens))
        out.append("")
        q = lambda ids: "[" + ", ".join(f'"{s}"' for s in ids) + "]"
        out.append(f"[Face-{n}][Sensors]\nhighPrioritySensorIds={q(s for s, _, _ in sensors)}\n"
                   f"lowPrioritySensorIds={q(s for s, _, _ in low)}\ntotalSensors=[]\n")
        if extra:
            out.append(f"[Face-{n}][{chart}][General]")
            out.extend(f"{k}={v}" for k, v in extra.items())
            out.append("")

    def layout(self, title, rows):
        """rows: list of (heightMode, columns); column = list of face numbers, "|" for a separator."""
        seps = iter(range(1901, 2000))
        rows = [(m, [[next(seps) if f == "|" else f for f in col] for col in cols if col]) for m, cols in rows]
        rows = [(m, cols) for m, cols in rows if cols]
        for _, cols in rows:
            for col in cols:
                for f in col:
                    if f > 1900:
                        self.out.append(f"[Face-{f}][Appearance]\nchartFace=org.kde.ksysguard.piechart\n")
        self.out.append(f"[page]\nTitle={title}\nactionsFace=\nicon=speedometer\nloadType=onstart\nmargin=2\nversion=1\n")
        for r, (mode, cols) in enumerate(rows):
            self.out.append(f"[page][row-{r}]\nTitle=\nheightMode={mode}\nisTitle=false\nname=row-{r}\n")
            for c, secs in enumerate(cols):
                self.out.append(f"[page][row-{r}][column-{c}]\nname=column-{c}\nnoMargins=false\nshowBackground=true\n")
                for s, f in enumerate(secs):
                    self.out.append(f"[page][row-{r}][column-{c}][section-{s}]\nface=Face-{f}\n"
                                    f"isSeparator={'true' if f > 1900 else 'false'}\nname=section-{s}\n")

    def text(self):
        return "\n".join(self.out).rstrip() + "\n"


def cpu_groups(threads):
    """Groups the threads by physical core; above 16 cores by L3 cache (CCD/CCX), if there is more than one."""
    cpu = "/sys/devices/system/cpu/cpu{}/{}"
    cores = {}
    for t in threads:
        key = (read(cpu.format(t, "topology/physical_package_id")), read(cpu.format(t, "topology/core_id")))
        cores.setdefault(key if None not in key else ("thread", t), []).append(t)
    if len(cores) > 16:
        l3 = {}
        for t in threads:
            l3.setdefault(read(cpu.format(t, "cache/index3/id")) or "0", []).append(t)
        if len(l3) > 1:
            return [(f"L3 {i}", ts) for i, ts in enumerate(l3.values())], len(cores)
    return [(f"Core {i + 1}", ts) for i, ts in enumerate(cores.values())], len(cores)


def cpu_model():
    """Short CPU name: "AMD Ryzen 7 9700X 8-Core Processor" -> "Ryzen 7 9700X"."""
    for line in (read("/proc/cpuinfo") or "").splitlines():
        if line.startswith("model name"):
            name = line.split(":", 1)[1]
            name = re.sub(r"\((R|TM|tm)\)|\bCPU\b|@.*|\d+-Core|\bProcessor\b|^\s*\d+(st|nd|rd|th) Gen\b|\b(AMD|Intel)\b", " ", name)
            return " ".join(name.split()) or "CPU"
    return "CPU"


def os_version_label():
    """Label of os/system/version: "Fedora base" when PRETTY_NAME was changed by a derivative (e.g. HorizonOS), otherwise "Version"."""
    info = dict(re.findall(r'^(\w+)="?([^"\n]*)"?$', read("/etc/os-release") or "", re.M))
    base = info.get("NAME", "").split(" ")[0]
    return f"{base} base" if base and base not in info.get("PRETTY_NAME", "") else "Version"


def temperature_kind(chip, sensor, name, cpu_temp):
    """Kind of an lm-sensors temperature ("RAM", "NVMe", ..., "board"), or None to skip it."""
    kind = chip.split("-")[0]
    if kind.startswith(CPU_CHIPS) and cpu_temp or kind.startswith(GPU_CHIPS):
        return None
    if kind.startswith(("spd5118", "jc42", "ee1004")):
        return "RAM"
    if kind.startswith("nvme"):
        return "NVMe" if sensor == "temp1" else None
    if kind.startswith("drivetemp"):
        return "SATA"
    if "mdio" in chip or kind.startswith(("r8169", "igc", "e1000e", "atlantic")):
        return "NIC"
    if kind.startswith(("mt79", "mt76", "iwlwifi", "ath", "rtw")):
        return None  # WiFi
    generic = not name or re.fullmatch(r"(Temperature|temp) ?\d+", name, re.I)
    if cpu_temp and not generic and re.search(r"cpu|tctl|tccd|tdie|peci", name, re.I):
        return None  # the CPU is already there
    return "board"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("-o", "--output", help=".page file to write (default: stdout)")
    parser.add_argument("--title", default="System", help="page title (default: System)")
    args = parser.parse_args()

    sensors = sensor_list()
    if not sensors:
        sys.exit("No sensors from kstatsviewer: is ksystemstats installed and running?")
    has = sensors.__contains__

    threads = sorted(int(m.group(1)) for s in sensors if (m := re.fullmatch(r"cpu/cpu(\d+)/usage", s)))
    gpus = sorted({m.group(1) for s in sensors if (m := re.fullmatch(r"gpu/(gpu\d+)/usage", s))}, key=lambda g: int(g[3:]))
    devices = sorted(d for s in sensors if (m := re.fullmatch(r"disk/([^/]+)/read", s)) and DEVICE.match(d := m.group(1)))
    filesystems = [m.group(1) for s in sensors
                   if (m := re.fullmatch(r"disk/([^/]+)/usedPercent", s)) and m.group(1) != "all" and not DEVICE.match(m.group(1))]
    temps = sorted((s for s in sensors if re.fullmatch(r"lmsensors/[^/]+/temp\d+", s)), key=natural)
    fans = sorted((s for s in sensors if re.fullmatch(r"lmsensors/[^/]+/fan\d+", s)), key=natural)
    power = next((s for s in sorted(sensors) if re.fullmatch(r"scripts/[^/]+/[^/]*(rapl|package|cpu)[^/]*", s, re.I)), None)

    values = sample(temps + fans + [f"disk/{f}/total" for f in filesystems]
                    + [s for s in ("cpu/all/averageTemperature", *(f"gpu/{g}/temperature" for g in gpus)) if has(s)])
    valid_temp = lambda s: isinstance(values.get(s), float) and 0 < values[s] < 115
    cpu_temp = has("cpu/all/averageTemperature") and valid_temp("cpu/all/averageTemperature")

    page = Page()
    faces = {}

    # System tiles
    page.face(1001, "local.graduatedbars", [],
              low=[(s, l, c) for s, l, c in [("os/system/prettyName", "Operating system", BLUE), ("os/system/version", os_version_label(), BLUE),
                                             ("os/kernel/version", "Kernel", GREEN), ("os/plasma/plasmaVersion", "KDE Plasma", PURPLE),
                                             ("os/system/uptime", "Uptime", YELLOW)] if has(s)],
              extra=dict(extraAsTiles="true", tileColumns=5))

    # CPU
    page.face(1010, "org.kde.ksysguard.linechart",
              [("cpu/all/system", "System", "85,255,255"), ("cpu/all/user", "User", BLUE), ("cpu/all/wait", "I/O wait", RED)],
              low=[("cpu/all/usage", "Total", "61,233,118")], title="CPU",
              extra=dict(historyAmount=120, lineChartFillOpacity=50, lineChartStacked="true", rangeAutoY="false", rangeFromY=0, rangeToY=100,
                         showGridLines="true", **LINE))

    # Cores: bar = usage, text = usage and frequency; above them, the CPU summary tiles
    groups, cores = cpu_groups(threads)
    max_mhz = int(-(-int(read("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq") or 0) // 100000) * 100) or 6000
    power_top = max(70, round(cores * 9, -1))  # the chart's scale; the tiles go 20 W higher
    tiles = [("cpu/all/usage", "Usage", BLUE, None),
             (power, "Package power", ORANGE, f"0:{power_top + 20}"),
             ("cpu/all/averageFrequency", "Average clock", PURPLE, f"0:{max_mhz}"),
             ("cpu/all/maximumFrequency", "Max clock", PURPLE, f"0:{max_mhz}"),
             ("cpu/all/averageTemperature" if cpu_temp else None, "Temperature", RED, "30:95"),
             *((f"cpu/loadaverages/loadaverage{m}", f"Load {m} min", TEAL, f"0:{len(threads)}") for m in (1, 5, 15))]
    tiles = [t for t in tiles if t[0] and has(t[0])]
    page.face(1002, "local.graduatedbars",
              [(f"cpu/cpu{t}/usage", label, BLUE) for label, ts in groups for t in ts],
              low=[(f"cpu/cpu{t}/frequency", label, None) for label, ts in groups for t in ts if has(f"cpu/cpu{t}/frequency")]
              + [(s, l, c) for s, l, c, _ in tiles], title=cpu_model(),
              extra=dict(extraAsTiles="true", groupByLabel="true", lowPriorityAsText="true", rangeAuto="true",
                         ranges="; ".join(f"{s}={r}" for s, _, _, r in tiles if r), showBarValue="true", showPeak="false",
                         tileColumns=4, useGradient="true"))

    # Memory
    page.face(1041, "org.kde.ksysguard.linechart",
              [("memory/physical/usedPercent", "Used", GREEN), ("memory/physical/cachePercent", "Cache", "150,204,188")],
              low=[("memory/physical/used", "In use", None), ("memory/physical/cache", "Cached", None),
                   ("memory/physical/free", "Free", None), ("memory/physical/total", "Total", None)], title="Memory",
              extra=dict(historyAmount=300, lineChartFillOpacity=40, lineChartStacked="true", rangeAutoY="false", rangeFromY=0, rangeToY=100,
                         showGridLines="true", **LINE))

    # Temperatures, in TEMP_ORDER
    found = {"CPU": [], "GPU": [], "board": [], "RAM": [], "NVMe": [], "SATA": [], "NIC": []}
    if cpu_temp:
        found["CPU"].append(("cpu/all/averageTemperature", "CPU"))
    found["GPU"] = [(f"gpu/{g}/temperature", "GPU") for g in gpus if valid_temp(f"gpu/{g}/temperature")]
    for s in temps:
        _, chip, sensor = s.split("/")
        kind = temperature_kind(chip, sensor, sensors[s], cpu_temp)
        if kind and valid_temp(s):
            found[kind].append((s, sensors[s] if kind == "board" else kind))
    temp_items, board_colors, spare = [], iter(BOARD_COLORS + SPARE), iter(SPARE * 3)
    for slot in TEMP_ORDER + ["board"] * len(found["board"]):
        items = found[slot][:1] if slot == "board" else found[slot]
        found[slot] = found[slot][len(items):]
        for i, (s, label) in enumerate(items):
            color = next(board_colors) if slot == "board" else TEMP_COLORS[slot] if i == 0 else next(spare)
            temp_items.append((s, label, color))
    temp_items = [(s, l, c) for (s, l), (_, _, c) in zip(numbered([(s, l) for s, l, _ in temp_items]), temp_items)]
    chart = lambda lo, hi, fill: dict(historyAmount=300, lineChartFillOpacity=fill, rangeAutoY="false", rangeFromY=lo, rangeToY=hi,
                                      showGridLines="true", showYAxisLabels="true", **LINE)
    if temp_items:
        page.face(1081, "org.kde.ksysguard.linechart", temp_items, title="Temperatures", extra=dict(chart(30, 70, 0), lineChartStacked="false"))
        faces["temps"] = 1081

    # CPU power (only from a ksystemstats script) and fans
    if power:
        page.face(1083, "org.kde.ksysguard.linechart", [(power, "CPU package", ORANGE)], title="CPU power", extra=chart(10, power_top, 25))
        faces["power"] = 1083
    fan_items = numbered([(s, re.sub(r"(?<=.) Fan\b", " fan", sensors[s]) or s.rsplit("/", 1)[1])
                          for s in fans if isinstance(values.get(s), float) and values[s] > 0])
    if fan_items:
        top = max(values[s] for s, _ in fan_items)
        page.face(1082, "org.kde.ksysguard.linechart", [(s, l, FAN_COLORS[i % len(FAN_COLORS)]) for i, (s, l) in enumerate(fan_items)],
                  title="Fans" if len(fan_items) > 1 else "Fan", extra=chart(0, max(2000, int(-(-top * 1.6 // 500)) * 500), 25))
        faces["fans"] = 1082

    # GPU
    if gpus:
        one = len(gpus) == 1
        name = lambda g, what: what if one else f"GPU {int(g[3:]) + 1} {what.lower()}"
        page.face(1050, "org.kde.ksysguard.linechart",
                  [(f"gpu/{g}/usage", "Usage" if one else f"GPU {int(g[3:]) + 1}", c) for g, c in zip(gpus, [PURPLE, TEAL, ORANGE, BLUE])],
                  low=[(f"gpu/{g}/{s}", name(g, l), None) for g in gpus
                       for s, l in [("coreFrequency", "Core clock"), ("usedVram", "VRAM")] if has(f"gpu/{g}/{s}")],
                  title="GPU", extra=dict(historyAmount=120, lineChartFillOpacity=30, rangeAutoY="false", rangeFromY=0, rangeToY=100, **LINE))
        faces["gpu"] = 1050

    # Disks: NVMe / SATA when there is only one of that kind, otherwise the device name
    disk_items = []
    for d, (cr, cw) in zip(devices[:4], DISK_COLORS):
        kind = "NVMe" if d.startswith("nvme") else "SATA" if d.startswith("sd") else None
        same = [x for x in devices if x[:2] == d[:2]]
        label = kind if kind and len(same) == 1 else d
        disk_items += [(f"disk/{d}/read", f"{label} R", cr), (f"disk/{d}/write", f"{label} W", cw)]
    if disk_items:
        page.face(1060, "org.kde.ksysguard.linechart", disk_items, title="Disks", extra=dict(historyAmount=120, lineChartFillOpacity=25, **LINE))
        faces["disks"] = 1060

    # Disk space: the root filesystem first, then the largest ones; nothing below 8 GB, at most 3
    mounts = {}
    for line in run(["findmnt", "-rno", "TARGET,UUID"]).splitlines():
        target, _, uuid = line.partition(" ")
        if uuid:
            mounts.setdefault(uuid, []).append(target)
    root = next((u for u, ts in mounts.items() if "/" in ts), None) or next((u for u, ts in mounts.items() if "/sysroot" in ts), None)
    size = lambda f: values.get(f"disk/{f}/total") if isinstance(values.get(f"disk/{f}/total"), float) else 0
    filesystems = sorted((f for f in filesystems if size(f) >= 8e9 or f == root), key=lambda f: (f != root, -size(f)))[:3]
    space, space_titles = [], []
    for f, color in zip(filesystems, SPACE_COLORS):
        title = "System" if f == root else (sensors.get(f"disk/{f}") or min(mounts.get(f, [f]), key=len).rsplit("/", 1)[-1] or f)
        title = title[:1].upper() + title[1:]
        space += [(f"disk/{f}/usedPercent", f"{title} used", color), (f"disk/{f}/free", f"{title} free", color)]
        space_titles.append(title)
    if space:
        # Tiles: used with its small bar, free next to it without one (range 0:0)
        page.face(1063, "local.graduatedbars", [], low=space, title="Disk space",
                  extra=dict(extraAsTiles="true", ranges="; ".join(f"{s}=0:0" for s, _, _ in space[1::2]), tileColumns=2))
        faces["space"] = 1063

    # Network: the interface of the default route
    iface = next(iter(re.findall(r"\bdev (\S+)", run(["ip", "route", "show", "default"]))), None)
    if not has(f"network/{iface}/download"):
        iface = next((m.group(1) for s in sorted(sensors) if (m := re.fullmatch(r"network/([^/]+)/download", s))
                      and m.group(1) not in ("all", "lo")), None)
    if iface:
        page.face(1070, "org.kde.ksysguard.linechart", [(f"network/{iface}/download", "Down", BLUE), (f"network/{iface}/upload", "Up", ORANGE)],
                  low=[(f"network/{iface}/totalDownload", "Received", None), (f"network/{iface}/totalUpload", "Sent", None)], title="Network",
                  extra=dict(historyAmount=120, lineChartFillOpacity=25, **LINE))
        faces["net"] = 1070

    get = lambda key: [faces[key]] if key in faces else []
    side = [f for f in (faces.get("power"), faces.get("fans")) if f]
    page.layout(args.title, [
        ("minimum", [[1001]]),
        ("balanced", [[1010], [1002], [1041]]),
        ("balanced", [get("temps"), sum(([f, "|"] for f in side), [])[:-1]]),
        ("minimum", [get("gpu"), get("disks"), get("space"), get("net")]),
    ])

    log(f"CPU: {cpu_model()}, {len(threads)} threads in {len(groups)} groups ({groups[0][0]}…{groups[-1][0]})" if groups else "CPU: no threads")
    log(f"Temperatures: {', '.join(l for _, l, _ in temp_items) or 'none'}")
    log(f"Fans: {', '.join(l for _, l in fan_items) or 'none'}; CPU power: {power or 'none'}")
    log(f"GPU: {', '.join(gpus) or 'none'}; disks: {', '.join(devices) or 'none'}; network: {iface or 'none'}")
    log(f"Disk space: {', '.join(space_titles) or 'none'}")

    text = page.text()
    if args.output:
        with open(args.output, "w") as f:
            f.write(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
