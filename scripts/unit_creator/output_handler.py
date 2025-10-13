from typing import List, Dict

class OutputHandler:
    messages: List[str] = []
    errors: List[str] = []
    warnings: List[str] = []

    @classmethod
    def info(cls, msg: str) -> None:
        line = f"[INFO] {msg}"
        cls.messages.append(line)
        print(line, flush=True)

    @classmethod
    def warn(cls, msg: str) -> None:
        line = f"[WARN] {msg}"
        cls.warnings.append(line)
        print(line, flush=True)

    @classmethod
    def error(cls, msg: str) -> None:
        line = f"[ERROR] {msg}"
        cls.errors.append(line)
        print(line, flush=True)

    @classmethod
    def missing_abilities(cls, missing: List[str]) -> None:
        if not missing:
            return
        cls.warn(f"Abilities: {', '.join(missing)} are not defined in ability sources")

    @classmethod
    def cloner_error(cls, name: str, err: Exception) -> None:
        cls.error(f"{name}: {err}")

    @classmethod
    def summary(cls) -> None:
        print("\n===== Unit Creator Summary =====", flush=True)
        if cls.messages:
            print("- Messages:", flush=True)
            for m in cls.messages:
                print(f"  {m}", flush=True)
        if cls.warnings:
            print("- Warnings:", flush=True)
            for w in cls.warnings:
                print(f"  {w}", flush=True)
        if cls.errors:
            print("- Errors:", flush=True)
            for e in cls.errors:
                print(f"  {e}", flush=True)
        print("===== End Summary =====", flush=True)
