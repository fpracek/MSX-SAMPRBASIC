#!/usr/bin/env python3
"""OPTION TARGET BIN: compiled under MSX-DOS (QBC -> QBCB -> NAME.BIN), then MSX-BASIC is started without DOS with only the .BIN on the disk:
CLEAR 200,&H83FF / BLOAD"BT.BIN",R. usage: python btest.py"""
import os
import shutil
import subprocess
import sys

import qtest
import mtest

BUILD, DISK = qtest.BUILD, qtest.DISK
nl = chr(10)
bs = chr(92)
FAILS = 0


def check(c, m):
    global FAILS
    print(('  ok   ' if c else '  FAIL ') + m)
    if not c:
        FAILS += 1


SRC = nl.join(['OPTION TARGET BIN', 'PRINT "ciao bin"', 'PRINT 6 * 7', 'FOR i = 1 TO 3 : PRINT i; : NEXT', 'PRINT',
               'DIM a(3)', 'a(2) = 5', 'PRINT a(2) + 1', 'SUB ds(n$)', '  PRINT "sub "; n$', 'END SUB', 'CALL ds("x")', 'END', ''])


def main():
    qtest.build_all()
    mtest.make_disk({'BT.SPB': SRC})
    for a, b in (('qbcb.com', 'QBCB.COM'), ('rtbin.bin', 'RTBIN.BIN')):
        shutil.copy(os.path.join(BUILD, a), os.path.join(DISK, b))
    print('--- compilazione sotto DOS')
    tcl = [qtest.TCL, 'set OUTDIR "%s"' % BUILD.replace(bs, '/'), 'after time 20 {type "QBC BT.SPB%sr"}' % bs,
           'after time 70 {dump bt_end}', 'after time 71 exit']
    open(os.path.join(BUILD, 'btest.tcl'), 'w').write(nl.join(tcl))
    subprocess.run([qtest.OPENMSX, '-machine', 'Philips_NMS_8250', '-diska', DISK, '-script', os.path.join(BUILD, 'btest.tcl')], timeout=600)
    scr = ''.join(l.rstrip() for l in open(os.path.join(BUILD, 'bt_end.txt')))
    check('BIN written: BT.BIN' in scr, 'messaggio di fine compilazione: ' + scr[-80:])
    binp = os.path.join(DISK, 'bt.bin')
    check(os.path.exists(binp), 'BT.BIN prodotto')
    if not os.path.exists(binp):
        sys.exit(1)
    data = open(binp, 'rb').read()
    start = data[1] | data[2] << 8
    end = data[3] | data[4] << 8
    ex = data[5] | data[6] << 8
    check(data[0] == 0xFE and start == 0x8400 and ex == 0x8400 and end == start + len(data) - 8, 'intestazione BLOAD: inizio %04X fine %04X esecuzione %04X (%d byte)' % (start, end, ex, len(data)))
    print('--- esecuzione da MSX-BASIC (senza DOS)')
    bdir = os.path.join(BUILD, 'basicdisk')
    if os.path.isdir(bdir):
        shutil.rmtree(bdir)
    os.makedirs(bdir)
    shutil.copy(binp, os.path.join(bdir, 'BT.BIN'))
    tcl = [qtest.TCL, 'set OUTDIR "%s"' % BUILD.replace(bs, '/'),
           'after time 25 {type "CLEAR 200,&H83FF%sr"}' % bs,
           'after time 28 {type "BLOAD%s"BT.BIN%s",R%sr"}' % (bs, bs, bs),
           'after time 45 {dump bt_run}',
           'after time 46 {keymatrixdown 7 128; after time 0.15 {keymatrixup 7 128}}',
           'after time 50 {dump bt_back}', 'after time 51 exit']
    open(os.path.join(BUILD, 'btest2.tcl'), 'w').write(nl.join(tcl))
    subprocess.run([qtest.OPENMSX, '-machine', 'Philips_NMS_8250', '-diska', bdir, '-script', os.path.join(BUILD, 'btest2.tcl')], timeout=600)
    rows = [l.rstrip() for l in open(os.path.join(BUILD, 'bt_run.txt'))]
    txt = nl.join(rows)
    check('ciao bin' in txt, 'il programma stampa: ' + txt[:200].replace(nl, ' / '))
    check(' 42' in txt and ' 1  2  3' in txt and ' 6' in txt and 'sub x' in txt, 'calcoli, array e SUB corretti')
    back = nl.join(l.rstrip() for l in open(os.path.join(BUILD, 'bt_back.txt')))
    check('Ok' in back, "dopo un tasto si torna al prompt di MSX-BASIC: " + back[-120:].replace(nl, ' / '))
    print('FALLITI: %d' % FAILS)
    sys.exit(1 if FAILS else 0)


if __name__ == '__main__':
    main()
