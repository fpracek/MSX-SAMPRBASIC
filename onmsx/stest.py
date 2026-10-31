#!/usr/bin/env python3
"""Test del suono: compila e avvia i programmi di stests/ su openMSX, registra i registri del PSG ogni 50 ms
e confronta le sequenze con i .chk. uso: python stest.py [nome ...]
.chk: 'seq C P1 P2 ...' = periodi (registri 0-1/2-3/4-5) della voce C (0-2) quando il volume e' > 0, senza ripetizioni;
      'reg N V' = ultimo valore del registro N; 'dur C P MIN MAX' = quanto dura il periodo P sulla voce C (secondi)"""
import os, shutil, subprocess, sys
import qtest

HERE = qtest.HERE
BUILD = qtest.BUILD
DISK = qtest.DISK
STESTS = os.path.join(HERE, 'stests')
DOSDIR = qtest.DOSDIR
FAILS = 0
STEP = 0.05


def check(c, m):
    global FAILS
    print(('  ok   ' if c else '  FAIL ') + m)
    if not c:
        FAILS += 1


TCL = r'''
set throttle off
catch {set renderer none}
proc poll {f n} {
    set d [debug read_block "PSG regs" 0 16]
    binary scan $d c* b
    puts $f $b
    if {$n > 0} { after time %s [list poll $f [expr {$n - 1}]] } else { close $f }
}
''' % STEP


def main():
    qtest.build_all()
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(STESTS) if f.endswith('.bas'))
    if os.path.isdir(DISK):
        shutil.rmtree(DISK)
    os.makedirs(DISK)
    for f in ('MSXDOS.SYS', 'COMMAND.COM'):
        shutil.copy(os.path.join(DOSDIR, f), DISK)
    shutil.copy(os.path.join(BUILD, 'qbc.com'), os.path.join(DISK, 'QBC.COM'))
    shutil.copy(os.path.join(BUILD, 'qbstub.com'), os.path.join(DISK, 'QB.COM'))
    shutil.copy(os.path.join(BUILD, 'rt.bin'), os.path.join(DISK, 'RT.BIN'))
    lines = [TCL]
    t = 20.0
    for n in names:
        src = open(os.path.join(STESTS, n + '.bas')).read()
        open(os.path.join(DISK, n.upper() + '.BAS'), 'wb').write(src.replace('\n', '\r\n').encode('latin-1'))
        lines.append('after time %.1f {type "QBC %s.BAS\\r"}' % (t, n.upper()))
        # il compilatore impiega circa 12 s; poi il programma suona
        lines.append('after time %.1f {poll [open "%s/%s.psg" w] %d}' % (t + 1, BUILD.replace(chr(92), '/'), n, int(40 / STEP)))
        t += 52.0
        lines.append('after time %.1f {reset}' % t)
        t += 20.0
    lines.append('after time %.1f exit' % (t + 1))
    tcl = os.path.join(BUILD, 'stest.tcl')
    open(tcl, 'w').write('\n'.join(lines))
    machine = os.environ.get('GMACHINE', 'Philips_NMS_8250')
    subprocess.run([qtest.OPENMSX, '-machine', machine, '-diska', DISK, '-script', tcl], timeout=3000)
    for n in names:
        print('---', n)
        p = os.path.join(BUILD, n + '.psg')
        if not os.path.exists(p):
            check(False, 'nessun log')
            continue
        regs = [[int(x) & 255 for x in ln.split()] for ln in open(p) if ln.strip()]
        for ln in open(os.path.join(STESTS, n + '.chk')):
            w = ln.split()
            if not w or w[0].startswith('#'):
                continue
            if w[0] == 'seq':
                c = int(w[1])
                want = [int(x) for x in w[2:]]
                got = []
                for r in regs:
                    per = r[2 * c] | ((r[2 * c + 1] & 15) << 8)
                    if r[8 + c] & 15 and (not got or got[-1] != per):
                        got.append(per)
                check(got == want, f'voce {c}: periodi {got} (attesi {want})')
            elif w[0] == 'reg':
                rn, v = int(w[1]), int(w[2])
                got = regs[-1][rn]
                check(got == v, f'R{rn} = {got} (atteso {v})')
            elif w[0] == 'dur':
                c, per, lo, hi = int(w[1]), int(w[2]), float(w[3]), float(w[4])
                cnt = sum(1 for r in regs if (r[2 * c] | ((r[2 * c + 1] & 15) << 8)) == per and r[8 + c] & 15)
                d = cnt * STEP
                check(lo <= d <= hi, f'voce {c} periodo {per}: {d:.2f} s (attesi {lo}-{hi})')
            elif w[0] == 'maxvol':                      # volume massimo raggiunto dalla voce C
                c, v = int(w[1]), int(w[2])
                got = max(r[8 + c] & 15 for r in regs)
                check(got == v, f'voce {c}: volume massimo {got} (atteso {v})')
            elif w[0] == 'anysound':                    # almeno una voce ha volume > 0 in qualche istante (BEEP)
                ok = any(any(r[8 + i] & 31 for i in range(3)) for r in regs)
                check(ok, 'suono udibile')
            elif w[0] == 'chord':                       # tutte le voci suonano contemporaneamente: periodi alla stessa riga
                want = [int(x) for x in w[1:4]]
                ok = any([r[0] | ((r[1] & 15) << 8), r[2] | ((r[3] & 15) << 8), r[4] | ((r[5] & 15) << 8)] == want and
                         all(r[8 + i] & 15 for i in range(3)) for r in regs)
                check(ok, f'accordo {want}')
    print('FALLITI: %d' % FAILS)
    sys.exit(1 if FAILS else 0)


if __name__ == '__main__':
    main()
