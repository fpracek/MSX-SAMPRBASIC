#!/usr/bin/env python3
"""Cartucce a segmenti su piu' file (NOME000, NOME001, ...): compilazione e collegamento in una ROM, rinvio al file 000,
errori nel file giusto, OPTION fuori dal file 000. uso: python mtest.py"""
import os
import shutil
import subprocess
import sys

import qtest

HERE, BUILD, DISK = qtest.HERE, qtest.BUILD, qtest.DISK
FAILS = 0


def check(c, m):
    global FAILS
    print(('  ok   ' if c else '  FAIL ') + m)
    if not c:
        FAILS += 1


MAIN = '''OPTION TARGET SCC
PRINT "main"
CALL FAR hello(3)
PRINT twice(21)
msg "ciao"
PRINT "end"
END
'''
S1 = '''SUB hello(n)
  PRINT "hello from seg1:"; n
  CALL inner(n)
END SUB
SUB inner(n)
  PRINT "inner"; n * 2
END SUB
'''
S2 = '''FUNCTION twice(x)
  twice = x * 2
END FUNCTION
SUB msg(s$)
  PRINT s$; "!"
END SUB
'''
EXP = ['main', 'hello from seg1: 3', 'inner 6', ' 42', 'ciao!', 'end']


def make_disk(files):
    if os.path.isdir(DISK):
        shutil.rmtree(DISK)
    os.makedirs(DISK)
    for f in ('MSXDOS.SYS', 'COMMAND.COM'):
        shutil.copy(os.path.join(qtest.DOSDIR, f), DISK)
    for a, b in (('qbc.com', 'QBC.COM'), ('qbstub.com', 'SAMPRBAS.COM'), ('rt.bin', 'RT.BIN'), ('rtrom.bin', 'RTROM.BIN'),
                 ('qasm.ovl', 'QASM.OVL'), ('qbcr.com', 'QBCR.COM')):
        shutil.copy(os.path.join(BUILD, a), os.path.join(DISK, b))
    for n, src in files.items():
        open(os.path.join(DISK, n), 'wb').write(src.replace('\n', '\r\n').encode('latin-1'))


def compile_case(tag, files, cmd, wait=40.0):
    make_disk(files)
    bs = chr(92)
    tcl = [qtest.TCL, 'set OUTDIR "%s"' % BUILD.replace(bs, '/'),
           'after time 20 {type "QBC %s%sr"}' % (cmd, bs),
           'after time %.1f {dump %s_end}' % (20 + wait, tag),
           'after time %.1f {keymatrixdown 7 128; after time 0.15 {keymatrixup 7 128}}' % (21 + wait),
           'after time %.1f {dump %s_after}' % (25 + wait, tag),
           'after time %.1f exit' % (26 + wait)]
    open(os.path.join(BUILD, 'mtest.tcl'), 'w').write('\n'.join(tcl))
    for f in (tag + '_end.txt', tag + '_after.txt'):
        p = os.path.join(BUILD, f)
        if os.path.exists(p):
            os.remove(p)
    subprocess.run([qtest.OPENMSX, '-machine', os.environ.get('GMACHINE', 'Philips_NMS_8250'), '-diska', DISK,
                    '-script', os.path.join(BUILD, 'mtest.tcl')], timeout=600)
    rd = lambda n: [l.rstrip() for l in open(os.path.join(BUILD, n))] if os.path.exists(os.path.join(BUILD, n)) else []
    return rd(tag + '_end.txt'), rd(tag + '_after.txt')


def main():
    qtest.build_all()
    print('--- A: FAUST000/001/002, si parte dal file del segmento 2')
    end, after = compile_case('ma', {'FAUST000.SPB': MAIN, 'FAUST001.SPB': S1, 'FAUST002.SPB': S2}, 'FAUST002.SPB')
    rom = os.path.join(DISK, 'faust.rom')
    check(os.path.exists(rom), 'ROM FAUST.ROM prodotta: %s' % sorted(os.listdir(DISK)))
    if os.path.exists(rom):
        size = os.path.getsize(rom)
        check(size >= 16384 + 8192 * 2, 'dimensione %d (almeno 3 segmenti)' % size)
        shutil.copy(rom, os.path.join(BUILD, 'faust.rom'))
        tcl = qtest.TCL + '\nset OUTDIR "%s"\nafter time 16 {dump mrom}\nafter time 18 exit\n' % BUILD.replace(chr(92), '/')
        open(os.path.join(BUILD, 'mtest2.tcl'), 'w').write(tcl)
        subprocess.run([qtest.OPENMSX, '-machine', os.environ.get('GMACHINE', 'Philips_NMS_8250'), '-cart', os.path.join(BUILD, 'faust.rom'),
                        '-romtype', 'KonamiSCC', '-script', os.path.join(BUILD, 'mtest2.tcl')], timeout=300)
        got = [l.rstrip() for l in open(os.path.join(BUILD, 'mrom.txt'))]
        ok = got[:len(EXP)] == EXP
        check(ok, 'schermo della ROM uguale a quello atteso')
        if not ok:
            for i, e in enumerate(EXP):
                print('   exp %-24r got %r' % (e, got[i] if i < len(got) else '<->'))
    txt = ''.join(after + end)
    check('FAUST002.SPB' in txt, "ritorno all'editor con il nome ricevuto: " + txt[-60:])

    print('--- B: errore di sintassi nel file 001 (riga 3)')
    bad = S1.replace('  CALL inner(n)', '  CALL inner(n) +')
    end, after = compile_case('mb', {'FAUST000.SPB': MAIN, 'FAUST001.SPB': bad, 'FAUST002.SPB': S2}, 'FAUST000.SPB', wait=30.0)
    txt = ''.join(end + after)
    check('FAUST001.SPB' in txt and 'E3 ' in txt + ' ', "errore riportato sul file 001 riga 3: " + txt[-70:])

    print('--- C: OPTION nel file 002')
    end, after = compile_case('mc', {'FAUST000.SPB': MAIN, 'FAUST001.SPB': S1, 'FAUST002.SPB': 'OPTION DEBUG\n' + S2}, 'FAUST000.SPB', wait=30.0)
    txt = ''.join(end + after)
    check('FAUST002.SPB' in txt and 'E1 13' in txt, "OPTION fuori dal file 000: errore 13 sul file 002: " + txt[-70:])
    print('FALLITI: %d' % FAILS)
    sys.exit(1 if FAILS else 0)


if __name__ == '__main__':
    main()
