"""Runs grumpy-gambling's Lua tests in a real Lua 5.4 (lupa). Not shipped with the resource.
Usage: python run_tests.py   (needs Python 3.12 + `pip install lupa`)"""
import sys, pathlib
from lupa import lua54

ROOT = pathlib.Path(__file__).resolve().parent.parent
HARNESS = r'''
Test = { passed = 0, failed = 0 }
local out = print
function Test.ok(c, msg) if c then Test.passed = Test.passed + 1 else Test.failed = Test.failed + 1; out('  FAIL: ' .. msg) end end
function Test.eq(a, b, msg) Test.ok(a == b, msg .. ' (got ' .. tostring(a) .. ', want ' .. tostring(b) .. ')') end
function Test.near(a, b, eps, msg) Test.ok(type(a) == 'number' and math.abs(a - b) <= eps, msg .. ' (got ' .. tostring(a) .. ', want ~' .. tostring(b) .. ')') end
'''

def run(files):
    bad = 0
    for f in files:
        L = lua54.LuaRuntime(unpack_returned_tuples=True)
        L.execute(HARNESS)
        load = L.eval('function(src, name) local fn, err = load(src, "@" .. name) if not fn then error(err) end return fn() end')
        try:
            for dep in DEPS.get(f.name, []):
                if dep.startswith('lua:'):
                    L.execute(dep[4:])
                else:
                    load((ROOT / dep).read_text(encoding='utf-8'), dep)
            load(f.read_text(encoding='utf-8'), f.name)
        except Exception as e:
            print(f'ERROR {f.name}: {e}'); bad += 1; continue
        p, fl = L.eval('Test.passed'), L.eval('Test.failed')
        print(f'{"OK  " if fl == 0 else "FAIL"} {f.name}: {p} passed, {fl} failed'); bad += fl
    return bad

SERVER = ['tests/fakes.lua', 'shared/config.lua', 'shared/geometry.lua', 'shared/models.lua',
          'server/main.lua', 'server/money.lua', 'server/db.lua', 'server/registry.lua', 'server/tables.lua',
          'server/rake.lua', 'server/house.lua', 'server/hands.lua', 'server/wallet.lua', 'server/seats.lua', 'server/npc.lua',
          'tests/fake_db.lua']
DEPS = {
    'test_money.lua': ['server/money.lua'],
    'test_hands.lua': SERVER,
    'test_lib.lua': ['lib/init.lua', 'lib/cards.lua', 'lib/poker.lua', 'lib/betting.lua'],
    # the dev test games live in a sibling resource (builds/grumpy-gambling-test) and are loaded "inside" it
    'test_play.lua': SERVER + ['server/play.lua', 'lua:GG.Ready = true', 'lua:Fake.resource = "grumpy-gambling-test"',
                               'lib/init.lua', 'lib/cards.lua', 'lib/poker.lua', 'lib/betting.lua', 'lib/server.lua',
                               '../grumpy-gambling-test/server/showdown.lua', '../grumpy-gambling-test/server/highcard.lua',
                               'lua:Fake.resource = "grumpy-gambling"'],
}
if __name__ == '__main__':
    tests = sorted((ROOT / 'tests').glob('test_*.lua'))
    sys.exit(1 if run(tests) else 0)
