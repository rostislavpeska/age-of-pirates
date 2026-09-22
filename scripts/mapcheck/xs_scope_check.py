"""XS scope check (S6): the errors the XS compiler stops on and mapcheck never saw - a variable used before its
declaration, declared twice in one function (XS has NO block scope: every declaration inside an if / for body belongs
to the function), a function called before its definition, an identifier the compiler has never heard of.

The builtin catalogue is the engine's own: the function table and EXTERN constants of any CXSDump the game wrote
(RandMaps/Age3DERM<map>.dmp.txt); the newest dump in the profile folder is used unless one is passed.

  python scripts/mapcheck/xs_scope_check.py randmaps/zplondon.xs [more.xs ...] [--dump FILE] [--verbose]
Exit 1 when any file has findings.
"""
import re, sys, glob, os
from pathlib import Path

PROFILE = Path(r"C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238")
KEYWORDS = {"if", "else", "for", "while", "return", "break", "continue", "true", "false", "int", "float", "string", "bool",
            "vector", "void", "const", "static", "extern", "include", "rule", "active", "inactive", "minInterval",
            "maxInterval", "highFrequency", "runImmediately", "group", "priority", "label", "goto", "switch", "case",
            "default", "class", "dbg", "breakpoint", "infiniteLoop"}
TYPES = ("int", "float", "string", "bool", "vector", "void")
NL = chr(10)
BS = chr(92)


def builtins_from_dump(dump: Path):
    t = dump.read_text(encoding="utf-8", errors="replace")
    funcs = set(re.findall(r"^\s*(?:void|int|float|string|bool|vector)\s+(\w+)\(", t, re.M))
    consts = set(re.findall(r"EXTERN\$(\w+)", t))
    return funcs, consts


def strip(src: str) -> str:
    """One pass: string literals -> quotes with spaces inside, // and /* */ comments -> spaces (newlines kept)."""
    out = []; i = 0; n = len(src)
    while i < n:
        c = src[i]
        if c == '"':
            j = i + 1
            while j < n and src[j] != '"' and src[j] != NL:
                j += 2 if src[j] == BS else 1
            closed = j < n and src[j] == '"'
            out.append('"' + " " * (min(j, n) - i - 1) + ('"' if closed else "")); i = j + 1 if closed else j
        elif src.startswith("//", i):
            j = src.find(NL, i); j = n if j < 0 else j
            out.append(" " * (j - i)); i = j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2); j = n if j < 0 else j + 2
            out.append("".join(NL if ch == NL else " " for ch in src[i:j])); i = j
        else:
            out.append(c); i += 1
    return "".join(out)


def line_of(src, pos): return src.count(NL, 0, pos) + 1


def functions(src):
    """(name, params, body_start, body_end, sig_pos) for every function incl. main; body = matching braces."""
    out = []
    for m in re.finditer(r"^\s*(?:void|int|float|string|bool|vector)\s+(\w+)\s*\(([^)]*)\)\s*\{", src, re.M):
        depth = 0; i = m.end() - 1
        while i < len(src):
            if src[i] == "{": depth += 1
            elif src[i] == "}":
                depth -= 1
                if depth == 0: break
            i += 1
        params = [p.strip().split("=")[0].split()[-1] for p in m.group(2).split(",") if p.strip()]
        out.append((m.group(1), params, m.end(), i, m.start()))
    return out


def check(path: Path, funcs_builtin, consts_builtin, verbose=False):
    raw = path.read_text(encoding="utf-8", errors="replace"); src = strip(raw); findings = []
    fns = functions(src)
    fn_pos = {n: p for n, _, _, _, p in fns}
    in_fn = [(a, b) for _, _, a, b, _ in fns]
    def inside_fn(pos): return any(a <= pos <= b for a, b in in_fn)
    globals_ = {}
    for m in re.finditer(r"\b(int|float|string|bool|vector)\s+([A-Za-z_]\w*)\s*(?:=|;)", src):
        if not inside_fn(m.start()) and not re.search(r"\(\s*$", src[max(0, m.start() - 40):m.start()]):
            globals_.setdefault(m.group(2), m.start())
    for name, params, a, b, sigpos in fns:
        body = src[a:b]; declared = {}
        for p in params: declared[p] = a
        for m in re.finditer(r"\b(int|float|string|bool|vector)\s+([A-Za-z_]\w*)\s*(=|;)", body):
            v = m.group(2); pos = a + m.start()
            if v in declared and declared[v] != a:
                findings.append((line_of(src, pos), name, "DOUBLE", "%s declared again in %s (first at line %d)" % (v, name, line_of(src, declared[v]))))
            else:
                declared.setdefault(v, pos)
        for m in re.finditer(r"\bfor\s*\(\s*([A-Za-z_]\w*)\s*=", body):
            v = m.group(1); pos = a + m.start()
            declared.setdefault(v, pos)
        for m in re.finditer(r"\b([A-Za-z_]\w*)\b", body):
            v = m.group(1); pos = a + m.start()
            nxt = body[m.end():m.end() + 2].lstrip()
            prev = body[max(0, m.start() - 12):m.start()]
            if v in KEYWORDS or re.fullmatch(r"\d+", v): continue
            if re.search(r"\b(int|float|string|bool|vector)\s*$", prev): continue          # the declaration itself
            if nxt.startswith("("):
                if v in funcs_builtin or v in ("xsVectorSet", "xsVectorGetX", "xsVectorGetY", "xsVectorGetZ"): continue
                if v in fn_pos:
                    if fn_pos[v] > sigpos and v != name: findings.append((line_of(src, pos), name, "ORDER", "%s() called before its definition (line %d)" % (v, line_of(src, fn_pos[v]))))
                    continue
                if v.startswith(("rm", "xs", "tr", "ai", "kb")): continue                   # engine calls not in this dump's table
                findings.append((line_of(src, pos), name, "UNKNOWN_FN", "%s() is not a known function" % v)); continue
            if v in declared:
                if declared[v] > pos: findings.append((line_of(src, pos), name, "BEFORE_DECL", "%s used before its declaration (line %d)" % (v, line_of(src, declared[v]))))
                continue
            if v in globals_ or v in consts_builtin: continue
            if re.fullmatch(r"c[A-Z]\w*", v): continue                                       # engine constants cNumber..., cTech..., cElev...
            findings.append((line_of(src, pos), name, "UNDEFINED", "%s is not declared anywhere before use" % v))
    seen = set(); out = []
    for f in sorted(findings):
        k = (f[0], f[3])
        if k not in seen: seen.add(k); out.append(f)
    return out


def main(argv):
    dump = None; verbose = "--verbose" in argv
    if "--dump" in argv: dump = Path(argv[argv.index("--dump") + 1])
    files = [Path(a) for a in argv if a.endswith(".xs")]
    if dump is None:
        cands = sorted((PROFILE / "RandMaps").glob("Age3DERM*.dmp.txt"), key=lambda p: p.stat().st_mtime)
        dump = cands[-1]
    funcs_b, consts_b = builtins_from_dump(dump)
    print("builtins from %s: %d functions, %d constants" % (dump.name, len(funcs_b), len(consts_b)))
    bad = 0
    for f in files:
        res = check(f, funcs_b, consts_b, verbose)
        print("%-40s %s" % (f.name, "OK" if not res else "%d finding(s)" % len(res)))
        for line, fn, kind, msg in res[:40]:
            print("    line %5d  %-10s [%s] %s" % (line, fn, kind, msg))
        bad += bool(res)
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
