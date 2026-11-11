"""Read a Windows minidump and name the crash: exception code + faulting
module + offset. Pure stdlib - no WinDbg needed.

    python scripts/aitest/crashdump_triage.py <file.dmp>
    python scripts/aitest/crashdump_triage.py            (newest dump)

The module+offset pair is the attribution: AoE3DE_s.exe = engine (report a
build bug / suspect data), a d3d/nv/amd dll = graphics driver, ntdll/heap =
memory corruption (often bad data reaching the engine).
"""
import glob
import os
import struct
import sys

DUMPDIR = os.path.join(os.path.expanduser("~"), "Games",
                       "Age of Empires 3 DE", "CrashDumps")

EXC_NAMES = {
    0xC0000005: "ACCESS_VIOLATION",
    0xC0000094: "INTEGER_DIVIDE_BY_ZERO",
    0xC00000FD: "STACK_OVERFLOW",
    0xC0000374: "HEAP_CORRUPTION",
    0x80000003: "BREAKPOINT",
    0xC000001D: "ILLEGAL_INSTRUCTION",
    0xE06D7363: "CPP_EXCEPTION",
}


def read_dump(path):
    data = open(path, "rb").read()
    assert data[:4] == b"MDMP", "not a minidump"
    n_streams, dir_rva = struct.unpack_from("<II", data, 8)
    streams = {}
    for i in range(n_streams):
        stype, size, rva = struct.unpack_from("<III", data, dir_rva + 12 * i)
        streams.setdefault(stype, (size, rva))

    modules = []
    if 4 in streams:  # ModuleListStream
        size, rva = streams[4]
        count = struct.unpack_from("<I", data, rva)[0]
        off = rva + 4
        for i in range(count):
            base, imgsize = struct.unpack_from("<QI", data, off)
            name_rva = struct.unpack_from("<I", data, off + 20)[0]
            nlen = struct.unpack_from("<I", data, name_rva)[0]
            name = data[name_rva + 4:name_rva + 4 + nlen].decode("utf-16-le")
            modules.append((base, imgsize, name))
            off += 108

    exc = None
    if 6 in streams:  # ExceptionStream
        size, rva = streams[6]
        tid = struct.unpack_from("<I", data, rva)[0]
        code, flags = struct.unpack_from("<II", data, rva + 8)
        addr = struct.unpack_from("<Q", data, rva + 24)[0]
        exc = (tid, code, addr)
    return modules, exc


def main():
    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        dumps = sorted(glob.glob(os.path.join(DUMPDIR, "*.dmp")),
                       key=os.path.getmtime)
        if not dumps:
            print("no dumps in %s (LocalDumps armed? crash happened?)" % DUMPDIR)
            return
        path = dumps[-1]
    print("dump: %s (%.1f MB)" % (path, os.path.getsize(path) / 1048576.0))
    modules, exc = read_dump(path)
    if exc is None:
        print("no exception stream (not a crash dump?)")
        return
    tid, code, addr = exc
    print("exception: 0x%08X %s  thread %d  address 0x%X"
          % (code, EXC_NAMES.get(code, "?"), tid, addr))
    hit = None
    for base, size, name in modules:
        if base <= addr < base + size:
            hit = (name, addr - base)
            break
    if hit:
        print("faulting module: %s + 0x%X" % (os.path.basename(hit[0]), hit[1]))
        print("full path: %s" % hit[0])
    else:
        print("address maps to no loaded module (JIT/corrupted call target)")
        near = min(modules, key=lambda m: abs(m[0] - addr)) if modules else None
        if near:
            print("nearest module: %s @ base 0x%X" % (os.path.basename(near[2]), near[0]))


if __name__ == "__main__":
    main()
