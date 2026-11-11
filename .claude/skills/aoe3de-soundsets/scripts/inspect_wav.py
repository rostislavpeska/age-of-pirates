"""Inspect a voice WAV for a cut that kept the tail of the previous sentence.

A 20 ms window above -32 dB is speech. A bad cut is a speech burst of 160 ms or
less, then a pause of 120 ms or more, then the rest of the line. The Korean monk
KnockOut 1 take (2026-10-13) was that shape: 100 ms of the previous sentence,
200 ms of quiet, then the line. A syllable gap inside one phrase is shorter and
is not flagged.

Usage: python inspect_wav.py line.wav|folder [more ...]
Exit 1 when any file has a leading fragment.
"""
import math
import sys
import wave
from array import array
from pathlib import Path

SPEECH_DB = -32.0
WINDOW_S = 0.02
MAX_FRAGMENT_S = 0.16
MIN_GAP_S = 0.12


def read_mono(path):
    with wave.open(str(path), "rb") as handle:
        channels = handle.getnchannels()
        width = handle.getsampwidth()
        rate = handle.getframerate()
        frames = handle.getnframes()
        raw = handle.readframes(frames)
    if width != 2:
        raise SystemExit("%s: expected 16-bit PCM, got %s-byte samples" % (path, width))
    data = array("h")
    data.frombytes(raw)
    if channels != 1:
        data = array("h", data[::channels])
    return rate, data


def window_db(data, start, end):
    count = end - start
    if count <= 0:
        return -120.0
    total = 0
    for index in range(start, end):
        sample = data[index]
        total += sample * sample
    rms = math.sqrt(total / count)
    if rms < 1.0:
        return -120.0
    return 20.0 * math.log10(rms / 32768.0)


def speech_runs(data, rate):
    window = max(1, int(rate * WINDOW_S))
    runs = []
    start = None
    levels = []
    for offset in range(0, len(data) - window + 1, window):
        level = window_db(data, offset, offset + window)
        levels.append(level)
        index = len(levels) - 1
        if level > SPEECH_DB and start is None:
            start = index
        elif level <= SPEECH_DB and start is not None:
            runs.append((start * WINDOW_S, index * WINDOW_S))
            start = None
    if start is not None:
        runs.append((start * WINDOW_S, len(levels) * WINDOW_S))
    return runs, levels


def leading_fragment(runs):
    """Return (fragment_s, gap_s) when the start is a leftover, else None."""
    if len(runs) < 2:
        return None
    fragment = runs[0][1] - runs[0][0]
    gap = runs[1][0] - runs[0][1]
    if fragment <= MAX_FRAGMENT_S and gap >= MIN_GAP_S:
        return fragment, gap
    return None


def shape(levels):
    marks = []
    for level in levels:
        if level > -25.0:
            marks.append("#")
        elif level > -35.0:
            marks.append("+")
        elif level > -45.0:
            marks.append(".")
        else:
            marks.append(" ")
    return "".join(marks)


def inspect(path):
    rate, data = read_mono(path)
    runs, levels = speech_runs(data, rate)
    return {
        "duration": len(data) / float(rate) if rate else 0.0,
        "runs": runs,
        "fragment": leading_fragment(runs),
        "shape": shape(levels),
    }


def wavs(item):
    path = Path(item)
    if path.is_dir():
        found = sorted(path.glob("*.wav"))
        if not found:
            raise SystemExit("%s: no wav files" % path)
        return found
    return [path]


def main(argv):
    if len(argv) < 2:
        print("usage: inspect_wav.py line.wav|folder [more ...]", file=sys.stderr)
        return 2
    failed = 0
    for item in argv[1:]:
        for path in wavs(item):
            report = inspect(path)
            fragment = report["fragment"]
            if fragment:
                failed += 1
                status = "LEADING FRAGMENT %.2fs then %.2fs gap" % fragment
            else:
                status = "ok"
            print("%s  %.2fs  %s" % (path.name, report["duration"], status))
            print("  " + report["shape"])
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
