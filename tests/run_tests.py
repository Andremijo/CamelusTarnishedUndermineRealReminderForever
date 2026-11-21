"""Run the addon's Lua tests under Lua 5.1 (the version WoW uses).

    pip install lupa
    python3 tests/run_tests.py
"""
import os
import sys

from lupa import lua51

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)

lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute('ADDON_DIR = "TarnishedRealReminder/"')
for name in ("tests/wow_mock.lua", "tests/test_core.lua"):
    with open(name, encoding="utf-8") as f:
        code = f.read()
    try:
        lua.execute(code)
    except Exception as e:  # lupa raises LuaError
        print(f"{name}: {e}")
        sys.exit(1)
