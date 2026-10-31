#!/usr/bin/env python3
"""Collaudo della libreria in virgola mobile (rtfloat.asm) sull'emulatore Z80: confronto con i float a 24 bit di mantissa."""
import math
import os
import random
import re
import subprocess
import sys
from z80 import Z80Machine

HERE = os.path.dirname(os.path.abspath(__file__))
SJASM = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\sjasmplus-1.20.3.win\sjasmplus.exe'
RTRAM = 0xC090
FA, FB, FT = RTRAM + 0x210, RTRAM + 0x216, RTRAM + 0x21C
TRAP = 0xF000
FAILS = 0


def build():
    r = subprocess.run([SJASM, '--raw=build/fptest.bin', '--sym=build/fptest.sym', 'fptest.asm'], cwd=HERE, capture_output=True, text=True)
    if 'error' in r.stdout.lower().replace('0 errors', ''):
        print(r.stdout)
        sys.exit(2)
    sym = {}
    for ln in open(os.path.join(HERE, 'build', 'fptest.sym')):
        m = re.match(r'^(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)', ln)
        if m:
            sym[m.group(1)] = int(m.group(2), 16)
    return open(os.path.join(HERE, 'build', 'fptest.bin'), 'rb').read(), sym


CODE, SYM = build()


class M:
    def __init__(self):
        self.m = Z80Machine()
        for i, b in enumerate(CODE):
            self.m.memory[0x4000 + i] = b
        self.m.memory[TRAP] = 0x76
        self.m.set_breakpoint(TRAP)

    def call(self, name, **regs):
        m = self.m
        m.sp = 0xF000 - 2
        m.memory[m.sp] = TRAP & 255
        m.memory[m.sp + 1] = TRAP >> 8
        for k, v in regs.items():
            setattr(m, k, v)
        m.pc = SYM[name]
        for _ in range(2000):
            m.ticks_to_stop = 100000
            ev = m.run()
            if ev & 2 and m.pc == TRAP:
                return
        raise RuntimeError('timeout ' + name)

    def poke(self, addr, data):
        for i, b in enumerate(data):
            self.m.memory[addr + i] = b

    def peek(self, addr, n):
        return bytes(self.m.memory[addr:addr + n])


def pack(x):
    """float -> 4 byte MBF"""
    if x == 0:
        return bytes(4)
    s = 0x80 if x < 0 else 0
    m, e = math.frexp(abs(x))
    q = int(round(m * (1 << 24)))
    if q >= 1 << 24:
        q >>= 1
        e += 1
    e += 128
    if e <= 0:
        return bytes(4)
    return bytes([q & 255, (q >> 8) & 255, ((q >> 16) & 0x7F) | s, e])


def unpack(b):
    if b[3] == 0:
        return 0.0
    q = b[0] | (b[1] << 8) | ((b[2] | 0x80) << 16)
    v = math.ldexp(q / (1 << 24), b[3] - 128)
    return -v if b[2] & 0x80 else v


def check(c, msg):
    global FAILS
    if not c:
        FAILS += 1
        print('  FAIL', msg)


def rel(a, b):
    return abs(a - b) <= abs(b) * 2e-7 + 1e-30


def binop(mc, name, a, b):
    mc.poke(FT + 12, pack(a))
    mc.poke(FT + 16, pack(b))
    mc.call('fp_load', hl=FT + 12)         # FA = a
    mc.call('fp_loadb', hl=FT + 16)        # FB = b  (sinistro = b... si cambia sotto)
    mc.call(name)
    mc.call('fp_st', hl=FT + 20)
    return unpack(mc.peek(FT + 20, 4))


def main():
    rnd = random.Random(5)
    mc = M()
    vals = [0.0, 1.0, -1.0, 0.5, 2.0, 3.0, 10.0, 0.1, 100.0, 12345.678, 1e-5, 1e5, -7.25, 3.14159265]
    for _ in range(400):
        vals.append(rnd.choice([-1, 1]) * math.exp(rnd.uniform(-20, 20)))
    n = 0
    for _ in range(1500):
        a = rnd.choice(vals)
        b = rnd.choice(vals)
        a, b = unpack(pack(a)), unpack(pack(b))
        # FA = b (destro), FB = a (sinistro): risultato = a OP b
        mc.poke(FT + 12, pack(b))
        mc.poke(FT + 16, pack(a))
        for op, f in (('fp_add', lambda x, y: x + y), ('fp_sub', lambda x, y: x - y), ('fp_mul', lambda x, y: x * y), ('fp_div', lambda x, y: x / y if y else None)):
            if op == 'fp_div' and b == 0:
                continue
            mc.call('fp_load', hl=FT + 12)
            mc.call('fp_loadb', hl=FT + 16)
            mc.call(op)
            mc.call('fp_st', hl=FT + 20)
            got = unpack(mc.peek(FT + 20, 4))
            want = f(a, b)
            ok = (got == want == 0) or rel(got, want) or (abs(want) < 1e-30 and got == 0)
            if not ok and not (abs(want) > 1e38 or (want != 0 and abs(want) < 1e-37)):
                check(False, f'{op}({a}, {b}) = {got} (atteso {want})')
            n += 1
        # confronto
        mc.call('fp_load', hl=FT + 12)
        mc.call('fp_loadb', hl=FT + 16)
        mc.call('fp_cmp')
        z = bool(mc.m.f & 0x40)
        c = bool(mc.m.f & 0x01)
        check(z == (a == b) and c == (a < b), f'cmp({a}, {b}): Z={z} C={c}')
    # interi
    for i in list(range(-40, 41)) + [rnd.randint(-32768, 32767) for _ in range(300)] + [32767, -32768]:
        mc.call('fp_itof', hl=i & 0xFFFF)
        mc.call('fp_st', hl=FT + 20)
        check(unpack(mc.peek(FT + 20, 4)) == float(i), f'itof({i})')
        mc.call('fp_itof', hl=i & 0xFFFF)
        mc.call('fp_ftoi', a=1)
        check(mc.m.hl == (i & 0xFFFF), f'ftoi(itof({i}))')
    for x in [0.4, 0.5, 0.6, 1.5, 2.5, -0.5, -1.5, -2.4, 123.7, -123.7, 32767.4, -32768.0, 0.0]:
        mc.poke(FT + 12, pack(x))
        mc.call('fp_load', hl=FT + 12)
        mc.call('fp_ftoi', a=1)
        want = int(math.floor(abs(x) + 0.5)) * (-1 if x < 0 else 1)
        got = mc.m.hl - 65536 if mc.m.hl >= 32768 else mc.m.hl
        check(got == want, f'ftoi round({x}) = {got} (atteso {want})')
        mc.call('fp_load', hl=FT + 12)
        mc.call('fp_ftoi', a=0)
        want = int(x)
        got = mc.m.hl - 65536 if mc.m.hl >= 32768 else mc.m.hl
        check(got == want, f'ftoi trunc({x}) = {got} (atteso {want})')
    # funzioni
    def un(name, x, **kw):
        mc.poke(FT + 12, pack(x))
        mc.call('fp_load', hl=FT + 12)
        mc.call(name, **kw)
        mc.call('fp_st', hl=FT + 20)
        return unpack(mc.peek(FT + 20, 4))
    for _ in range(150):
        x = abs(unpack(pack(rnd.choice(vals)))) + 1e-3
        if x < 1e30 and x > 1e-30:
            g = un('rt_fsqr', x)
            check(rel(g, math.sqrt(x)) or abs(g - math.sqrt(x)) < 1e-6 * math.sqrt(x), f'sqr({x}) = {g} (atteso {math.sqrt(x)})')
            g = un('rt_flog', x)
            check(abs(g - math.log(x)) < 3e-6 * max(1, abs(math.log(x))), f'log({x}) = {g} (atteso {math.log(x)})')
    for _ in range(300):
        x = unpack(pack(rnd.uniform(-50, 50)))
        g = un('rt_fsin', x)
        check(abs(g - math.sin(x)) < 5e-6, f'sin({x}) = {g} (atteso {math.sin(x)})')
        g = un('rt_fcos', x)
        check(abs(g - math.cos(x)) < 5e-6, f'cos({x}) = {g} (atteso {math.cos(x)})')
        g = un('rt_fatn', x)
        check(abs(g - math.atan(x)) < 5e-6, f'atn({x}) = {g} (atteso {math.atan(x)})')
        xe = unpack(pack(rnd.uniform(-20, 20)))
        g = un('rt_fexp', xe)
        check(rel(g, math.exp(xe)) or abs(g - math.exp(xe)) < 3e-6 * math.exp(xe), f'exp({xe}) = {g} (atteso {math.exp(xe)})')
        xt = unpack(pack(rnd.uniform(-1.4, 1.4)))
        g = un('rt_ftan', xt)
        check(abs(g - math.tan(xt)) < 1e-4 * max(1, abs(math.tan(xt))), f'tan({xt}) = {g} (atteso {math.tan(xt)})')
    for x in [0.0, 0.5, -0.5, 1.5, -1.5, 2.0, -2.0, 123.75, -123.75, 40000.5, -40000.5, 1e7 + 0.5, 0.99]:
        g = un('fp_fix', x)
        check(g == float(math.trunc(unpack(pack(x)))), f'fix({x}) = {g}')
        g = un('fp_int', x)
        check(g == float(math.floor(unpack(pack(x)))), f'int({x}) = {g} (atteso {math.floor(unpack(pack(x)))})')
    def power(x, y):
        mc.poke(FT + 12, pack(y))
        mc.poke(FT + 16, pack(x))
        mc.call('fp_load', hl=FT + 12)
        mc.call('fp_loadb', hl=FT + 16)
        mc.call('rt_fpow')
        mc.call('fp_st', hl=FT + 20)
        return unpack(mc.peek(FT + 20, 4))
    for x, y in [(2, 10), (2, -3), (10, 5), (-2, 3), (-2, 4), (3, 0.5), (9, 0.5), (2.5, 2.5), (10, -2), (7, 1), (1.5, 20), (0, 3), (5, 0)]:
        g = power(x, y)
        w = x ** y if not (x < 0 and y != int(y)) else None
        check(w is None or rel(g, w) or abs(g - w) < 3e-5 * abs(w), f'pow({x}, {y}) = {g} (atteso {w})')
    # testo
    def fstr(x):
        mc.poke(FT + 12, pack(x))
        mc.call('fp_load', hl=FT + 12)
        mc.call('rt_fstr')
        n_ = mc.peek(RTRAM + 20, 1)[0]
        return mc.peek(RTRAM + 21, n_).decode()
    cases = [(0.5, ' .5'), (3.14159, ' 3.14159'), (100.0, ' 100'), (1234567.0, ' 1.23457E+06'), (1e10, ' 1E+10'), (0.001, ' 1E-03'),
             (-2.5, '-2.5'), (123456.0, ' 123456'), (0.01, ' .01'), (0.05, ' .05'), (1e-10, ' 1E-10'), (1e38, ' 1E+38'), (0.0, ' 0'),
             (1.0, ' 1'), (-1.0, '-1'), (7.25, ' 7.25'), (99999.9, ' 99999.9'), (999999.5, ' 1E+06'), (0.1, ' .1'), (1.5e-5, ' 1.5E-05'),
             (65536.0, ' 65536'), (12.5, ' 12.5'), (2.0 ** 20, ' 1.04858E+06')]
    for x, w in cases:
        g = fstr(x)
        check(g == w, f'str({x}) = {g!r} (atteso {w!r})')
    def fval(s):
        b = s.encode()
        mc.poke(RTRAM + 20, bytes([len(b)]) + b)
        mc.call('rt_fval', hl=RTRAM + 20)
        mc.call('fp_st', hl=FT + 20)
        return unpack(mc.peek(FT + 20, 4))
    for s, w in [('3.14', 3.14), ('-0.5', -0.5), ('1e5', 1e5), ('  12', 12.0), ('.5', 0.5), ('1E-3', 1e-3), ('123456789', 123456789.0), ('0.000123', 0.000123),
                 ('1.5e+3', 1500.0), ('abc', 0.0), ('', 0.0), ('+7', 7.0), ('2.5E10', 2.5e10), ('0', 0.0), ('99999999999', 99999999999.0), ('1E38', 1e38)]:
        g = fval(s)
        check(rel(g, w) or abs(g - w) < 3e-7 * abs(w), f'val({s!r}) = {g} (atteso {w})')
    print('FALLITI: %d (operazioni controllate: %d)' % (FAILS, n))
    sys.exit(1 if FAILS else 0)


if __name__ == '__main__':
    main()
