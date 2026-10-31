#!/usr/bin/env python3
"""Collaudo dell'assembler in linea (qasm.asm): esegue l'overlay sull'emulatore Z80, interpreta le righe "# ..."
prodotte e confronta i byte con quelli di sjasmplus per un corpus di istruzioni. uso: python asmtest.py [-v]"""
import os
import re
import subprocess
import sys
import tempfile
from z80 import Z80Machine

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, 'build')
SJASM = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\sjasmplus-1.20.3.win\sjasmplus.exe'
SRC = 0x4B00
TRAP = 0x0040
BASE = 0x1000
EXT = {'CONTA': 0xC2B0, 'FLAG': 0xC2C0, 'NOME$': 0xC300, 'FINE': 0x3456}


def build():
    r = subprocess.run([SJASM, '--raw=build/qasm.ovl', '--sym=build/qasm.sym', 'qasm.asm'], cwd=HERE, capture_output=True, text=True)
    if r.returncode != 0 or 'error' in r.stdout.lower().replace('0 errors', ''):
        print(r.stdout)
        sys.exit(2)
    return open(os.path.join(BUILD, 'qasm.ovl'), 'rb').read()


def run_overlay(ovl, text):
    m = Z80Machine()
    mem = m.memory
    for i, b in enumerate(ovl):
        mem[0x8000 + i] = b
    data = text.replace('\n', '\r\n').encode('latin-1') + b'\x00'
    for i, b in enumerate(data):
        mem[SRC + i] = b
    mem[0xF000 - 2] = TRAP & 255
    mem[0xF000 - 1] = TRAP >> 8
    m.sp = 0xF000 - 2
    m.pc = 0x8000
    m.hl = SRC
    m.bc = 0x3400
    m.set_breakpoint(TRAP)
    m.ticks_to_stop = 200_000_000
    while True:
        ev = m.run()
        if ev & 2 and m.pc == TRAP:
            break
    err = bool(m.f & 1)
    if err:
        return None, (m.a, m.de)
    out = bytearray()
    a = SRC
    while mem[a]:
        out.append(mem[a])
        a += 1
    return out.decode('latin-1'), None


def decode(out, base=BASE):
    """righe '# ...' -> byte (risolve +k e nomi)"""
    res = bytearray()
    for ln in out.split('\r\n'):
        if not ln.startswith('#'):
            if ln.strip():
                raise ValueError('riga non valida: %r' % ln)
            continue
        body = ln[1:].strip()
        if body.startswith('*'):
            body = body[1:].strip()
        if not body:
            continue
        for it in body.split(','):
            it = it.strip()
            if re.fullmatch(r'\d+', it):
                res.append(int(it))
            elif it.startswith('+'):
                v = base + int(it[1:])
                res += bytes([v & 255, v >> 8])
            elif ':' in it:
                n, nm = it.split(':')
                res.append(int(n))
                v = EXT[nm]
                res += bytes([v & 255, v >> 8])
            else:
                mm = re.fullmatch(r'([A-Z_$.][A-Z0-9_$.]*)(?:\+(\d+))?', it)
                if not mm:
                    raise ValueError('elemento %r' % it)
                v = EXT[mm.group(1)] + int(mm.group(2) or 0)
                res += bytes([v & 255, v >> 8])
    return bytes(res)


def reference(lines):
    hdr = '\n'.join('%s EQU %d' % (k.replace('$', '_S'), v) for k, v in EXT.items() if '$' not in k)
    hdr += '\nNOME_S EQU %d\n' % EXT['NOME$']
    def ind(l):
        return l if re.match(r'\S+:', l) or re.match(r'\S+\s+EQU', l, re.I) or not l.strip() else ' ' + l
    body = '\n'.join(ind(l.replace('NOME$', 'NOME_S')) for l in lines)
    src = '%s\n ORG %d\n%s\n' % (hdr, BASE, body)
    d = tempfile.mkdtemp()
    f = os.path.join(d, 'r.asm')
    open(f, 'w').write(src)
    r = subprocess.run([SJASM, '--raw=' + os.path.join(d, 'r.bin'), f], capture_output=True, text=True)
    if r.returncode != 0 or 'error' in r.stdout.lower().replace('0 errors', ''):
        return None, r.stdout
    return open(os.path.join(d, 'r.bin'), 'rb').read(), None


def corpus():
    L = []
    r8 = ['B', 'C', 'D', 'E', 'H', 'L', '(HL)', 'A']
    idx = ['(IX+5)', '(IY-3)', '(IX+0)', '(IY+127)', '(IX-128)', '(IX)']
    r16 = ['BC', 'DE', 'HL', 'SP']
    cc = ['NZ', 'Z', 'NC', 'C', 'PO', 'PE', 'P', 'M']
    for n in 'NOP HALT EXX DI EI DAA CPL SCF CCF RLCA RRCA RLA RRA NEG RETN RETI RRD RLD LDI LDIR LDD LDDR CPI CPIR CPD CPDR INI INIR IND INDR OUTI OTIR OUTD OTDR'.split():
        L.append(n)
    for a in r8:
        for b in r8:
            if a == '(HL)' and b == '(HL)':
                continue
            L.append('LD %s,%s' % (a, b))
    for a in r8:
        L.append('LD %s,0' % a)
        L.append('LD %s,255' % a)
        L.append('LD %s,-1' % a)
    for i in idx:
        for a in 'BCDEHLA':
            L.append('LD %s,%s' % (a, i))
            L.append('LD %s,%s' % (i, a))
        L.append('LD %s,77' % i)
    L += ['LD A,(BC)', 'LD A,(DE)', 'LD (BC),A', 'LD (DE),A', 'LD A,(1234)', 'LD (1234),A', 'LD A,I', 'LD A,R', 'LD I,A', 'LD R,A',
          'LD HL,(1234)', 'LD (1234),HL', 'LD IX,(1234)', 'LD (1234),IX', 'LD IY,(1234)', 'LD (1234),IY',
          'LD BC,(1234)', 'LD (1234),BC', 'LD DE,(1234)', 'LD (1234),DE', 'LD SP,(1234)', 'LD (1234),SP',
          'LD SP,HL', 'LD SP,IX', 'LD SP,IY', 'LD IX,4660', 'LD IY,4660']
    for r in r16:
        L.append('LD %s,4660' % r)
    for k in ['ADD', 'ADC', 'SUB', 'SBC', 'AND', 'XOR', 'OR', 'CP']:
        for a in r8:
            L.append('%s %s' % (k, a))
            if k in ('ADD', 'ADC', 'SBC'):
                L.append('%s A,%s' % (k, a))
        for i in idx[:4]:
            L.append('%s %s' % (k, i))
            if k in ('ADD', 'ADC', 'SBC'):
                L.append('%s A,%s' % (k, i))
        L.append('%s 100' % k)
        if k in ('ADD', 'ADC', 'SBC'):
            L.append('%s A,100' % k)
    for r in r16:
        L += ['ADD HL,%s' % r, 'ADC HL,%s' % r, 'SBC HL,%s' % r]
    for r in ('BC', 'DE', 'SP', 'IX'):
        L.append('ADD IX,%s' % r)
    for r in ('BC', 'DE', 'SP', 'IY'):
        L.append('ADD IY,%s' % r)
    for k in ('INC', 'DEC'):
        for a in r8:
            L.append('%s %s' % (k, a))
        for i in idx[:4]:
            L.append('%s %s' % (k, i))
        for r in r16 + ['IX', 'IY']:
            L.append('%s %s' % (k, r))
    L += ['JP 4660', 'JP (HL)', 'JP (IX)', 'JP (IY)', 'CALL 4660', 'RET']
    for c in cc:
        L += ['JP %s,4660' % c, 'CALL %s,4660' % c, 'RET %s' % c]
    for n in range(0, 0x39, 8):
        L.append('RST %d' % n)
    for r in ('BC', 'DE', 'HL', 'AF', 'IX', 'IY'):
        L += ['PUSH %s' % r, 'POP %s' % r]
    L += ['EX DE,HL', "EX AF,AF'", 'EX (SP),HL', 'EX (SP),IX', 'EX (SP),IY']
    for k in ['RLC', 'RRC', 'RL', 'RR', 'SLA', 'SRA', 'SRL']:
        for a in r8:
            L.append('%s %s' % (k, a))
        for i in idx[:4]:
            L.append('%s %s' % (k, i))
    for k in ['BIT', 'RES', 'SET']:
        for b in (0, 3, 7):
            for a in r8:
                L.append('%s %d,%s' % (k, b, a))
            for i in idx[:4]:
                L.append('%s %d,%s' % (k, b, i))
    L += ['IM 0', 'IM 1', 'IM 2', 'IN A,(5)', 'OUT (5),A', 'IN B,(C)', 'IN A,(C)', 'OUT (C),B', 'OUT (C),A', 'IN H,(C)', 'OUT (C),L']
    # formati numerici ed espressioni
    L += ['LD A,$1F', 'LD A,0x1F', 'LD A,1FH', 'LD A,0FFH', 'LD A,%101', 'LD A,101B', "LD A,'x'", 'LD HL,$1234', 'LD HL,0x1234',
          'LD HL,1234H', 'LD HL,65535', 'LD HL,2+3', 'LD HL,10-3', 'LD HL,$+5-$', 'LD A,10+5-3', 'LD A,-5']
    L += ['DB 1,2,3', 'DB "AB",0', 'DB "a;b"', 'DW 1234,$ABCD', 'DS 3', 'DS 4,7', 'DEFB 9', 'DEFW 77', 'DEFS 2']
    return L


def labeled():
    """prove con etichette locali, EQU e salti"""
    return [
        ['start:', 'LD A,5', 'loop: DEC A', 'JR NZ,loop', 'JP loop', 'CALL loop', 'JR end', 'NOP', 'DJNZ loop', 'end: RET'],
        ['VAL EQU 7', 'LD A,VAL', 'LD B,VAL+1', 'K: EQU 300', 'LD HL,K', 'LD HL,K*1+0' if False else 'LD HL,K+2'],
        ['a1: JR a1', 'JR Z,a1', 'JR NC,a2', 'a2: JR C,a1', 'JR $+4', 'NOP', 'NOP', 'DJNZ $'],
        ['fwd: JP fwd2', 'fwd2: LD HL,fwd', 'LD DE,fwd2', 'DW fwd,fwd2', 'LD A,fwd2-fwd', 'LD HL,(fwd)'],
        ['LD HL,(CONTA)', 'LD (CONTA),HL', 'LD A,(FLAG)', 'LD (FLAG),A', 'LD HL,CONTA', 'LD DE,CONTA+2', 'LD IX,CONTA', 'LD (CONTA),BC',
         'LD HL,NOME$', 'JP FINE', 'CALL FINE', 'JP Z,FINE', 'CALL NC,FINE', 'DW CONTA,FINE'],
        ['  ld a , 5   ; commento', '   LD  HL , ( 1234 )', 'ld (ix + 5) , b', 'Ld B,(Iy-2)', 'EX AF,AF\'  ; swap', ';solo commento', '', 'lab:'],
    ]


def main():
    verbose = '-v' in sys.argv
    ovl = build()
    print('QASM.OVL = %d byte' % len(ovl))
    fails = 0

    def check(lines, name):
        nonlocal fails
        text = '__ASM\n' + '\n'.join(lines) + '\n__ENDASM\n'
        out, err = run_overlay(ovl, text)
        ref, rerr = reference(lines)
        if ref is None:
            print('  RIF? %s: sjasmplus: %s' % (name, rerr.strip()[-300:]))
            return
        if out is None:
            fails += 1
            print('  FAIL %s: errore overlay %s (riga %d)  %r' % (name, err[0], err[1], lines[err[1] - 2] if 2 <= err[1] - 0 <= len(lines) + 1 else ''))
            return
        try:
            got = decode(out)
        except ValueError as e:
            fails += 1
            print('  FAIL %s: %s' % (name, e))
            return
        nlines = text.count('\n')
        if out.count('\r\n') != nlines:
            fails += 1
            print('  FAIL %s: righe %d != %d' % (name, out.count('\r\n'), nlines))
            return
        if got != ref:
            fails += 1
            print('  FAIL %s' % name)
            print('    exp', ref.hex())
            print('    got', got.hex())
            print(out[:400])
        elif verbose:
            print('  ok   %s (%d byte)' % (name, len(got)))

    L = corpus()
    # ogni istruzione da sola, preceduta da un'etichetta (le forme senza operandi relativi sono indipendenti)
    for i in range(0, len(L), 25):
        chunk = L[i:i + 25]
        text = '__ASM\n' + '\n'.join(chunk) + '\n__ENDASM\n'
        out, err = run_overlay(ovl, text)
        ref, rerr = reference(chunk)
        if ref is None:
            for ins in chunk:
                r1, e1 = reference([ins])
                if r1 is None:
                    print('  RIF? %r non accettata da sjasmplus' % ins)
            chunk = [c for c in chunk if reference([c])[0] is not None]
            if not chunk:
                continue
        if out is None or ref is None or decode(out) != ref or True:
            # ripete una per una per localizzare gli errori
            ok = out is not None and ref is not None
            if ok:
                try:
                    ok = decode(out) == ref
                except ValueError:
                    ok = False
            if not ok:
                for ins in chunk:
                    check([ins], ins)
    for k, lines in enumerate(labeled()):
        check(lines, 'etichette %d' % k)
    print('FALLITI: %d (corpus %d istruzioni)' % (fails, len(L)))
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
