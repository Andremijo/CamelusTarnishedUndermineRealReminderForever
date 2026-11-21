"""Run the addon's Lua tests under Lua 5.1 (the version WoW uses).

    pip install lupa
    python3 tests/run_tests.py

Each tests/test_*.lua file gets a fresh Lua state with the mocked client.
"""
import glob
import os
import sys

from lupa import lua51

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)

with open("tests/wow_mock.lua", encoding="utf-8") as f:
    mock = f.read()

failed = False
for path in sorted(glob.glob("tests/test_*.lua")):
    print(f"== {path}")
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute('ADDON_DIR = "TarnishedRealReminder/"')
    lua.execute(mock)
    with open(path, encoding="utf-8") as f:
        code = f.read()
    try:
        lua.execute(code)
    except Exception as e:  # lupa raises LuaError
        print(f"{path}: {e}")
        failed = True

sys.exit(1 if failed else 0)
