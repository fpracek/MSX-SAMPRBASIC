#!/usr/bin/env python3
"""Test del .COM dell'editor su MSX-DOS 1 (NMS-8250, cartella host come disco A:).

Verifica apertura da riga di comando, modifica, Ctrl+S, Ctrl+W (salva con nome),
conferma sulle modifiche non salvate, Ctrl+O, round-trip CR/LF di un file da 500 righe,
file troppo grande, Ctrl+Q con ritorno al prompt del DOS.
I byte dei file salvati si leggono direttamente dalla cartella host.
"""
import os
import re
import shutil
import subprocess
import sys

import etest
from etest import Scenario, check, load, BUILD, SJASM, OPENMSX, MACHINE

HERE = etest.HERE
DOSDIR = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\DISK2'
DISK = os.path.join(BUILD, 'disk')


def assemble_com():
    r = subprocess.run([SJASM, '-DCOM', f'--inc={HERE}', f'--sym={BUILD}\\ed.sym', 'editor.asm'],
                       cwd=HERE, capture_output=True, text=True)
    print(r.stdout.strip().split('\n')[-1])
    if r.returncode != 0 or 'error:' in (r.stdout + r.stderr).lower():
        print(r.stdout, r.stderr)
        sys.exit(2)
    shutil.copy(os.path.join(HERE, 'ed.com'), os.path.join(DISK, 'ED.COM'))
    syms = {}
    for ln in open(os.path.join(BUILD, 'ed.sym')):
        m = re.match(r'^(\w+): EQU 0x([0-9A-Fa-f]+)', ln)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return syms


def prepare_disk():
    if os.path.isdir(DISK):
        for f in os.listdir(DISK):
            os.remove(os.path.join(DISK, f))
    os.makedirs(DISK, exist_ok=True)
    for f in ('MSXDOS.SYS', 'COMMAND.COM'):
        shutil.copy(os.path.join(DOSDIR, f), DISK)
    open(os.path.join(DISK, 'HELLO.TXT'), 'wb').write(b'Hello MSX\r\n\tindented line\r\nthird line\r\n')
    med = ''.join(f'{i:04d} medium line number {i}\r\n' for i in range(1, 501)).encode()
    open(os.path.join(DISK, 'MED.TXT'), 'wb').write(med)
    big = ''.join(f'{i:05d} this is a long enough line to fill the buffer quickly\r\n' for i in range(1, 1201)).encode()
    open(os.path.join(DISK, 'BIG.TXT'), 'wb').write(big)
    return med, big


def chord(sc, *keys, gap=0.5):
    """keys = [(riga, maschera), ...] premuti insieme"""
    sc.do(' '.join(f'keymatrixdown {r} {m};' for r, m in keys) +
          ' after time 0.15 {' + ' '.join(f'keymatrixup {r} {m};' for r, m in keys) + '}', gap)


CTRL = (6, 0x02)
CTRL_S = (CTRL, (5, 0x01))
CTRL_W = (CTRL, (5, 0x10))
CTRL_O = (CTRL, (4, 0x10))
CTRL_Q = (CTRL, (4, 0x40))
CTRL_Z = (CTRL, (5, 0x80))
CTRL_Y = (CTRL, (5, 0x40))


def title(rows):
    return rows[0].replace('~', '')


def main():
    prepare_disk()
    syms = assemble_com()
    sc = Scenario(syms)
    sc.t = 20.0                              # boot del DOS e prompt A>
    sc.text('ED HELLO.TXT\\r', 8.0)
    sc.dump('c1_open')
    sc.text('X', 0.5)
    chord(sc, *CTRL_S, gap=5.0)
    sc.dump('c2_saved')
    chord(sc, *CTRL_W, gap=0.8)
    sc.dump('c3_prompt')
    sc.text('NEW.TXT\\r', 6.0)
    sc.dump('c4_saveas')
    sc.text('Q', 0.5)
    chord(sc, *CTRL_O, gap=0.8)
    sc.dump('c5_confirm')
    chord(sc, *CTRL_O, gap=0.8)
    sc.dump('c6_prompt2')
    sc.text('HELLO.TXT\\r', 5.0)
    sc.dump('c7_reopened')
    sc.do('keymatrixdown 6 1', 0.15)             # selezione e taglia/incolla anche sotto DOS
    sc.tap(8, 0x40, 1, 0.4)
    sc.do('keymatrixup 6 1', 0.2)
    chord(sc, CTRL, (5, 0x20), gap=0.8)         # Ctrl+X: taglia la prima riga
    sc.tap(8, 0x40, 2, 0.4)
    chord(sc, CTRL, (5, 0x08), gap=0.8)         # Ctrl+V: la incolla in fondo
    chord(sc, *CTRL_S, gap=5.0)
    sc.dump('c7b_cutpaste')
    chord(sc, *CTRL_Z, gap=1.0)                  # annulla l'incolla
    chord(sc, *CTRL_Z, gap=1.0)                  # annulla il taglio
    sc.dump('c7b2_undone')
    chord(sc, *CTRL_Y, gap=1.0)
    chord(sc, *CTRL_Y, gap=1.0)
    chord(sc, *CTRL_S, gap=5.0)                  # risalva: HELLO.TXT deve restare identico
    sc.dump('c7b3_redone')
    sc.tap(7, 0x04, 1, 0.5)                      # ESC: menu File
    sc.text('n', 1.0)                            # File > New (tasto rapido N)
    sc.dump('c7c_new')
    sc.tap(7, 0x04, 1, 0.5)                      # ESC, poi O: File > Open... dal menu
    sc.text('o', 1.0)
    sc.text('MED.TXT\\r', 15.0)
    sc.dump('c8_med')
    chord(sc, *CTRL_Z, gap=1.0)                  # dopo l'apertura la cronologia e' vuota
    sc.dump('c8b_noundo')
    chord(sc, *CTRL_W, gap=0.8)
    sc.text('COPY.TXT\\r', 25.0)
    sc.dump('c9_copy')
    chord(sc, *CTRL_O, gap=0.8)
    sc.text('BIG.TXT\\r', 35.0)
    sc.dump('c10_big')
    chord(sc, *CTRL_Q, gap=1.0)
    sc.t += 1.0
    sc.do('set ::nopatch 1', 0.1)        # l'editor e' uscito: la sua RAM non vale piu'
    sc.dump('c11_exit')

    tcl = os.path.join(BUILD, 'ecom.tcl')
    open(tcl, 'w').write(sc.script())
    for f in os.listdir(BUILD):
        if f.startswith('c') and f[1:2].isdigit() and f.endswith('.txt'):
            os.remove(os.path.join(BUILD, f))
    subprocess.run([OPENMSX, '-machine', MACHINE, '-diska', DISK, '-script', tcl], timeout=600)

    med = open(os.path.join(DISK, 'MED.TXT'), 'rb').read()
    print('--- c1 apertura da riga di comando')
    rows, vs, bl = load('c1_open')
    t = title(rows)
    check('Loaded 39 bytes' in t, 'messaggio di caricamento: ' + t[:40].strip())
    check(rows[1][:9] == 'Hello MSX' and rows[2][:17] == '    indented line' and rows[3][:10] == 'third line',
          f'contenuto: {rows[1][:12]!r} {rows[2][:18]!r} {rows[3][:10]!r}')
    check(vs['nlines'] == 4 and vs['len'] == 9 + 1 + 17 + 1 + 10 + 1, f'nlines={vs["nlines"]} len={vs["len"]}')
    check(t.startswith(' File  Edit  Find  Help'), 'barra dei menu presente (il messaggio sostituisce nome e stato)')

    print('--- c2 modifica e Ctrl+S')
    rows, vs, bl = load('c2_saved')
    t = title(rows)
    check('Saved' in t and 'bytes' in t, 'messaggio di salvataggio: ' + t[:46].strip())
    check(rows[1][:10] == 'XHello MSX', 'testo modificato visibile')
    hello = open(os.path.join(DISK, 'HELLO.TXT'), 'rb').read()
    exp = b'XHello MSX\r\n    indented line\r\nthird line\r\n'
    # (il contenuto salvato da Ctrl+S e' verificato da NEW.TXT, salvato subito dopo; HELLO.TXT viene poi riscritto)

    print('--- c3/c4 salva con nome')
    rows, vs, bl = load('c3_prompt')
    check('Save as:' in title(rows), 'prompt: ' + title(rows)[:30].strip())
    rows, vs, bl = load('c4_saveas')
    check('Saved' in title(rows), 'messaggio dopo save as: ' + title(rows)[:46].strip())
    new = os.path.join(DISK, 'NEW.TXT')
    check(os.path.exists(new) and open(new, 'rb').read() == exp, 'NEW.TXT creato con lo stesso contenuto')

    print('--- c5/c6/c7 conferma e riapertura')
    rows, vs, bl = load('c5_confirm')
    check('Unsaved' in title(rows), 'avviso modifiche non salvate: ' + title(rows)[:46].strip())
    rows, vs, bl = load('c6_prompt2')
    check('Open file:' in title(rows), 'secondo Ctrl+O apre il prompt')
    rows, vs, bl = load('c7_reopened')
    check(rows[1][:10] == 'XHello MSX', 'HELLO.TXT riaperto (ha la X salvata): ' + rows[1][:12])

    rows, vs, bl = load('c7b_cutpaste')
    exp2 = b'    indented line\r\nthird line\r\nXHello MSX\r\n'
    got2 = open(os.path.join(DISK, 'HELLO.TXT'), 'rb').read()
    check(got2 == exp2, f'taglia+incolla+salva: HELLO.TXT = {got2!r}')
    check('Saved' in title(rows), 'messaggio: ' + title(rows)[:40].strip())

    rows, vs, bl = load('c7b2_undone')
    check(rows[1][:10] == 'XHello MSX' and rows[2][:17] == '    indented line' and rows[3][:10] == 'third line' and vs['len'] == 39 + 1,
          f'dopo due Ctrl+Z il testo e\' quello di prima: {rows[1][:12]!r} {rows[3][:10]!r} len={vs["len"]}')
    rows, vs, bl = load('c7b3_redone')
    check(rows[1][:17] == '    indented line' and 'Saved' in title(rows), 'dopo due Ctrl+Y il testo e\' di nuovo tagliato/incollato e salvato')
    rows, vs, bl = load('c7c_new')
    check('New file' in title(rows) and vs['len'] == 0 and vs['nlines'] == 1, f'File > New: {title(rows)[19:40].strip()!r} len={vs["len"]} nlines={vs["nlines"]}')

    print('--- c8/c9 file da 500 righe: round trip')
    rows, vs, bl = load('c8_med')
    check(vs['nlines'] == 501, f'MED.TXT nlines={vs["nlines"]}')
    check(rows[1][:25] == '0001 medium line number 1' and rows[22].startswith('0022 medium line number'), 'prime righe')
    check(vs['len'] == len(med) - 500, f'len={vs["len"]} (atteso {len(med) - 500}, senza i CR)')
    rows, vs, bl = load('c8b_noundo')
    check('Nothing to undo' in title(rows) and vs['nlines'] == 501, 'Ctrl+Z dopo Open: ' + title(rows)[25:50].strip())
    cp = os.path.join(DISK, 'COPY.TXT')
    check(os.path.exists(cp) and open(cp, 'rb').read() == med, 'COPY.TXT identico a MED.TXT (CR/LF ricostruiti)')

    print('--- c10 file troppo grande')
    rows, vs, bl = load('c10_big')
    check('too large' in title(rows), 'messaggio: ' + title(rows)[:46].strip())
    check(vs['len'] > 20000 and vs['nlines'] > 300, f'troncato: len={vs["len"]} nlines={vs["nlines"]}')

    print('--- c11 uscita')
    rows, vs, bl = load('c11_exit')
    joined = ' '.join(rows.values())
    check('A>' in joined, 'ritorno al prompt del DOS')
    for n in ('c1_open', 'c3_prompt', 'c8_med'):
        etest.render(n)
    print('FALLITI:', etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
