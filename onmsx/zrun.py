#!/usr/bin/env python3
"""Esecuzione veloce e senza emulatore MSX: compila con QBC.COM (emulato con un BDOS finto),
poi esegue il programma generato (BIOS finto: CHPUT/CLS/POSIT/CHGET...) e restituisce lo schermo.
Serve per sviluppare/diagnosticare; la verifica finale resta qtest.py (openMSX vero)."""
import os
import sys
from z80 import Z80Machine

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, 'build')
LDR = 0xC000
BDOS_STUB = 0xF300
CALSLT = 0x001C
FILL = int(os.environ.get('ZFILL', '1'))


class Msx:
    def __init__(self, files):
        self.files = dict(files)            # NOME.EXT -> bytes
        self.m = Z80Machine()
        self.vlatch = None
        self.vptr = 0
        self.vr14 = 0
        self.m.set_input_callback(self._in)
        self.m.set_output_callback(self._out)
        self.m.set_get_int_vector_callback(lambda *a: 0xFF)
        self.dma = 0x80
        self.open = {}
        self.screen = [[' '] * 80 for _ in range(24)]
        self.row = self.col = 0
        self.keys = []
        self.vram = {}

    def _in(self, p):                       # VDP minimo: porta dati a 17 bit
        p &= 0xFF
        if p == 0x98:
            v = self.vram.get(self.vptr, 0)
            self.vptr += 1
            return v
        return 0x00 if p == 0x99 else 0xFF

    def _out(self, p, v):
        p &= 0xFF
        if p == 0x98:
            self.vram[self.vptr] = v
            self.vptr += 1
        elif p == 0x99:
            if self.vlatch is None:
                self.vlatch = v
            else:
                if v & 0x80:
                    if v & 0x3F == 14:
                        self.vr14 = self.vlatch & 7
                else:
                    self.vptr = (self.vr14 << 14) | ((v & 0x3F) << 8) | self.vlatch
                self.vlatch = None

    def w(self, addr, data):
        for i, b in enumerate(data):
            self.m.memory[addr + i] = b

    def r(self, addr, n):
        return bytes(self.m.memory[addr:addr + n])

    def r16(self, a):
        mm = self.m.memory
        return mm[a] | (mm[a + 1] << 8)

    def boot(self, com, tail):
        import random
        rnd = random.Random(FILL)
        self.w(0, bytes(rnd.randrange(256) for _ in range(0xF000)))
        self.w(0x100, com)
        t = (' ' + tail + '\r').encode()
        self.w(0x80, bytes([len(t)]) + t)
        self.w(5, b'\xC3' + BDOS_STUB.to_bytes(2, 'little'))
        self.w(6, BDOS_STUB.to_bytes(2, 'little'))
        self.w(BDOS_STUB, b'\xC9')
        self.w(CALSLT, b'\xC9')
        m = self.m
        m.sp = 0xF2F0
        m.pc = 0x100
        for a in (BDOS_STUB, CALSLT, LDR, LDR + 0x0E, 0):
            m.set_breakpoint(a)

    def fcbname(self, fcb):
        n = bytes(self.m.memory[fcb + 1:fcb + 9]).decode('latin-1').strip()
        e = bytes(self.m.memory[fcb + 9:fcb + 12]).decode('latin-1').strip()
        return n + '.' + e

    def bdos(self):
        m = self.m
        c = m.c
        de = m.de
        if c == 0x0F:                                   # open
            nm = self.fcbname(de)
            if nm in self.files:
                self.open[de] = nm
                m.a = 0
            else:
                m.a = 0xFF
        elif c == 0x10:
            m.a = 0
        elif c == 0x13:
            self.files.pop(self.fcbname(de), None)
            m.a = 0
        elif c == 0x16:
            nm = self.fcbname(de)
            self.files[nm] = b''
            self.open[de] = nm
            m.a = 0
        elif c == 0x1A:
            self.dma = de
        elif c == 0x27:                                 # lettura a blocchi, record da 1
            nm = self.open.get(de) or self.fcbname(de)
            pos = self.r16(de + 33)
            cnt = m.hl
            data = self.files[nm][pos:pos + cnt]
            self.w(self.dma, data)
            self.w(de + 33, (pos + len(data)).to_bytes(2, 'little'))
            m.a = 0 if len(data) == cnt else 1
            m.hl = len(data)
        elif c == 0x26:
            nm = self.open.get(de) or self.fcbname(de)
            pos = self.r16(de + 33)
            old = self.files[nm]
            if pos > len(old):
                old = old + bytes(pos - len(old))
            data = self.r(self.dma, m.hl)
            self.files[nm] = old[:pos] + data + old[pos + len(data):]
            self.w(de + 33, (pos + m.hl).to_bytes(2, 'little'))
            m.a = 0
        elif c == 0x23:                                 # dimensione del file (record da 1 byte)
            nm = self.open.get(de) or self.fcbname(de)
            self.w(de + 33, len(self.files[nm]).to_bytes(3, 'little'))
            m.a = 0
        else:
            raise RuntimeError('BDOS %02X non gestita' % c)

    def bios(self):
        m = self.m
        ix = m.ix
        if ix == 0x00A2:                                # CHPUT
            self.putc(m.a)
        elif ix == 0x006C:                              # INITXT
            self.screen = [[' '] * 80 for _ in range(24)]
            self.row = self.col = 0
            self.w(0xF3DD, bytes([1, 1]))
        elif ix == 0x00CC:                              # ERAFNK
            pass
        elif ix == 0x00C3:                              # CLS
            self.screen = [[' '] * 80 for _ in range(24)]
            self.row = self.col = 0
            self.w(0xF3DD, bytes([1]))
        elif ix == 0x00C6:                              # POSIT: H = colonna, L = riga (1-based)
            self.col, self.row = m.h - 1, m.l - 1
            self.w(0xF3DD, bytes([m.h]))
        elif ix in (0x0062, 0x005F):                    # CHGCLR / CHGMOD
            pass
        elif ix == 0x004A:                              # RDVRM
            m.a = self.vram.get(m.hl, 0)
        elif ix == 0x004D:                              # WRTVRM
            self.vram[m.hl] = m.a
        elif ix == 0x009F:                              # CHGET
            m.a = self.keys.pop(0) if self.keys else 13
        else:
            raise RuntimeError('BIOS %04X non gestita' % ix)

    def putc(self, ch):
        if ch == 13:
            self.col = 0
        elif ch == 10:
            self.row += 1
            if self.row >= 24:
                self.screen = self.screen[1:] + [[' '] * 80]
                self.row = 23
        elif 32 <= ch < 127:
            self.screen[self.row][self.col] = chr(ch)
            self.col += 1
            if self.col >= 80:
                self.col = 0
                self.row += 1
        self.w(0xF3DD, bytes([self.col + 1]))

    def run(self, limit=4_000_000_000):
        m = self.m
        steps = 0
        while True:
            m.ticks_to_stop = 70_000                    # circa un frame: JIFFY avanza (serve a SLEEP/TIMER)
            ev = m.run()
            steps += 70_000
            if not (ev & 2):
                j = (self.r16(0xFC9E) + 1) & 0xFFFF
                self.w(0xFC9E, j.to_bytes(2, 'little'))
            if ev & 2:
                pc = m.pc
                if pc == BDOS_STUB:
                    self.bdos()
                elif pc == CALSLT:
                    self.bios()
                elif pc == LDR + 0x0E:
                    return 'copy'
                elif pc == LDR:
                    return 'chain'
                elif pc == 0:
                    return 'reboot'
                continue
            if steps > limit:
                return 'timeout pc=%04X' % m.pc

    def lines(self):
        return [''.join(r).rstrip() for r in self.screen]


def compile_and_run(src, name='T.BAS', qbc=None, keys=(13,)):
    qbc = qbc or open(os.path.join(BUILD, 'qbc.com'), 'rb').read()
    ms = Msx({name: src.replace(chr(10), chr(13) + chr(10)).encode('latin-1'),
              'RT.BIN': open(os.path.join(BUILD, 'rt.bin'), 'rb').read()})
    ms.boot(qbc, name)
    res = ms.run()
    info = {'phase1': res}
    cname = name.rsplit('.', 1)[0] + '.COM'
    if res == 'chain':                                  # il caricatore e' pronto: QB.COM = errore di compilazione, altrimenti NOME.COM
        fn = ms.r(LDR + 3, 11)
        if fn.startswith(b'QB '):
            info['tail'] = ms.r(0x81, ms.m.memory[0x80]).decode('latin-1').strip()
            return info
        res = 'copy'
    if res != 'copy':
        return info
    image = ms.files.get(cname, b'')
    info['image'] = image
    info['disk_ok'] = len(image) > 0
    p = Msx({})
    p.keys = list(keys)
    p.boot(image, 'X')
    res2 = p.run()
    info['phase2'] = res2
    info['screen'] = p.lines()
    if res2 == 'chain':
        info['tail2'] = p.r(0x81, p.m.memory[0x80]).decode('latin-1').strip()
    return info


def norm(l):
    return l.rstrip()


if __name__ == '__main__':
    tests = os.path.join(HERE, '..', 'tests')
    qt = os.path.join(HERE, 'qtests')
    names = sys.argv[1:] or ['t1', 't6', 't7'] + sorted(f[:-4] for f in os.listdir(qt) if f.endswith('.bas') and not f.startswith(('f', 'm')) and 'OPTION TARGET' not in open(os.path.join(qt, f)).read())   # f*: file su disco, solo su openMSX
    fails = 0
    for n in names:
        d = qt if os.path.exists(os.path.join(qt, n + '.bas')) else tests
        src = open(os.path.join(d, n + '.bas')).read()
        exp = [norm(l) for l in open(os.path.join(d, n + '.exp')).read().rstrip(chr(10)).split(chr(10))]
        kf = os.path.join(d, n + '.keys')
        keys = [13 if c == chr(10) else ord(c) for c in open(kf).read()] if os.path.exists(kf) else [13]
        info = compile_and_run(src, 'T.BAS' if n[0] == 'e' else n.upper() + '.BAS', keys=keys)
        if exp[0].startswith('ERR '):
            ok = info.get('phase1') == 'chain' and info.get('tail') == exp[0][4:]
            print('%-4s %s  atteso %r  ottenuto %r' % (n, 'OK  ' if ok else 'FAIL', exp[0][4:], info.get('tail', info.get('phase1'))))
        else:
            got = [norm(l) for l in info.get('screen', [])[:len(exp)]]
            ok = got == exp and info.get('phase2') == 'chain' and info.get('disk_ok')
            print('%-4s %s' % (n, 'OK  ' if ok else 'FAIL'))
            if not ok:
                print('   fasi:', info.get('phase1'), info.get('phase2'), 'disk_ok', info.get('disk_ok'))
                for i in range(max(len(exp), len(got))):
                    print('   exp %-28r got %r' % (exp[i] if i < len(exp) else '-', got[i] if i < len(got) else '-'))
        fails += 0 if ok else 1
    print('FALLITI:', fails)
    sys.exit(1 if fails else 0)
