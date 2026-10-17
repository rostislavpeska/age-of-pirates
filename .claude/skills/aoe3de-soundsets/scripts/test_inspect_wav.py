"""The KnockOut 1 shape flags; a syllable gap inside one phrase does not."""
import math
import sys
import tempfile
import unittest
import wave
from array import array
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_wav import inspect  # noqa: E402

RATE = 22050


def tone(seconds, amplitude):
    count = int(RATE * seconds)
    return array("h", (
        int(amplitude * math.sin(2.0 * math.pi * 220.0 * index / RATE))
        for index in range(count)
    ))


def silence(seconds):
    return array("h", [0] * int(RATE * seconds))


def write(chunks):
    data = array("h")
    for chunk in chunks:
        data.extend(chunk)
    handle = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    handle.close()
    path = Path(handle.name)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(data.tobytes())
    return path


class InspectWav(unittest.TestCase):
    def test_leading_fragment_is_the_knockout_cut(self):
        # 100 ms of the previous sentence, 200 ms of quiet, then the line.
        path = write([silence(0.04), tone(0.10, 8000), silence(0.20), tone(0.40, 8000)])
        try:
            report = inspect(path)
        finally:
            path.unlink()
        self.assertIsNotNone(report["fragment"])
        fragment, gap = report["fragment"]
        self.assertAlmostEqual(fragment, 0.10, delta=0.03)
        self.assertGreaterEqual(gap, 0.12)

    def test_a_short_syllable_gap_is_one_phrase(self):
        path = write([silence(0.04), tone(0.24, 8000), silence(0.04), tone(0.30, 8000)])
        try:
            report = inspect(path)
        finally:
            path.unlink()
        self.assertIsNone(report["fragment"])


if __name__ == "__main__":
    unittest.main()
