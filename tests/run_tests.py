"""Run addon syntax checks and isolated Lua 5.1 specs from any directory.

Install the test dependency with:
    python -m pip install -r requirements-test.txt
Then run:
    python tests/run_tests.py
The project-local .work/python-packages installation is also supported.
"""

import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCAL_PACKAGES = ROOT / ".work" / "python-packages"
if LOCAL_PACKAGES.is_dir():
    sys.path.insert(0, str(LOCAL_PACKAGES))

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    raise SystemExit("Missing Lua 5.1 runtime: install requirements-test.txt with pip.")


def main():
    os.chdir(ROOT)
    failures = []
    modules = sorted((ROOT / "WowfPartyFrames").glob("*.lua"))
    specs = sorted((ROOT / "tests").glob("*_spec.lua"))
    if not modules or not specs:
        raise SystemExit("Expected addon Lua modules and at least one *_spec.lua test.")

    lua = LuaRuntime(unpack_returned_tuples=True)
    compile_file = lua.eval("function(path) local fn, err = loadfile(path); assert(fn, err) end")
    for module in modules:
        relative = module.relative_to(ROOT).as_posix()
        try:
            compile_file(relative)
        except Exception as error:
            failures.append(relative)
            print(f"FAIL syntax {relative}: {error}", flush=True)
    print(f"Checked Lua 5.1 syntax: {len(modules)} addon modules", flush=True)

    for spec in specs:
        relative = spec.relative_to(ROOT).as_posix()
        print(f"Running {relative}", flush=True)
        try:
            runtime = LuaRuntime(unpack_returned_tuples=True)
            runtime.execute(spec.read_text(encoding="utf-8-sig"))
        except Exception as error:
            failures.append(relative)
            print(f"FAIL {relative}: {error}", flush=True)

    if failures:
        print(f"Failed: {len(failures)} checks", flush=True)
        return 1
    print(f"Passed: {len(modules)} syntax checks and {len(specs)} isolated specs", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
