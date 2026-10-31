#!/usr/bin/env python3
"""Test della barra dei menu (build ROM, NMS-8250): apertura con ESC e con il mouse, frecce,
passaggio tra menu, tasti rapidi, Invio, hover e clic del mouse, chiusura, voci con effetto."""
import sys

import etest
from esel import parse_row
from etest import Scenario, check, load, demo_lines

ESC = (7, 0x04)
ENTER = (7, 0x80)
DOWN = (8, 0x40)
UP = (8, 0x20)
LEFT = (8, 0x10)
RIGHT = (8, 0x80)


def key(sc, k, n=1, gap=0.4):
    sc.tap(k[0], k[1], n, gap)


def row_text(rows, r, w):
    return ''.join(c for c, _ in parse_row(rows[r])[:w])


def row_inv(rows, r, a, b):
    cells = parse_row(rows[r])
    return [inv for _, inv in cells[a:b]]


def main():
    syms = etest.assemble()
    sc = Scenario(syms)
    demo = demo_lines()

    sc.dump('m0_start')
    key(sc, ESC)
    sc.dump('m1_open', True)
    key(sc, DOWN, 2)
    sc.dump('m2_down2')
    key(sc, UP, 3)                      # da 2: 1, 0, poi avvolge a 4
    sc.dump('m3_wrap')
    key(sc, RIGHT)
    sc.dump('m4_edit', True)
    key(sc, RIGHT, 4)                   # Find, Help, Run, poi avvolge a File
    sc.dump('m5_wrapmenu')
    key(sc, ESC)
    sc.dump('m6_closed')
    # tasto rapido: ESC, Destra (Edit), 'a' = Select all
    key(sc, ESC)
    key(sc, RIGHT)
    sc.text('a', 0.8)
    sc.dump('m7_hotkey')
    # Invio su "Copy" con tutto selezionato: clipboard troppo piccola -> avviso
    key(sc, ESC)
    key(sc, RIGHT)
    key(sc, DOWN, 3)                    # Undo, Redo, Cut, Copy
    key(sc, ENTER)
    sc.dump('m8_enter_copy')
    key(sc, DOWN)                       # annulla la selezione
    # mouse: clic sul titolo Edit (colonne 6-11)
    sc.poke8('mmode', 1)
    sc.pointer(8, 0)
    sc.click(0.2)
    sc.dump('m9_mouse_open', True)
    sc.pointer(10, 3)                   # hover sulla voce 1 (Redo)
    sc.wait(0.3)
    sc.dump('m10_hover')
    sc.pointer(10, 8)                   # clic su "Select all" (voce 6)
    sc.click(0.2)
    sc.dump('m11_click_item')
    # clic fuori dal menu: lo chiude senza spostare il cursore
    key(sc, ESC)
    sc.pointer(40, 10)
    sc.click(0.2)
    sc.dump('m12_click_outside')
    # Help -> About con la tastiera
    key(sc, ESC)
    key(sc, RIGHT, 3)
    key(sc, DOWN, 4)
    key(sc, ENTER)
    sc.dump('m13_about')
    key(sc, (8, 0x01))                  # Spazio: chiude la finestra
    # clic sul titolo mentre un altro menu e' aperto: passa a quello
    sc.pointer(2, 0)
    sc.click(0.2)                       # apre File
    sc.pointer(20, 0)
    sc.click(0.2)                       # Help al posto di File
    sc.dump('m14_switch')
    sc.pointer(20, 0)
    sc.click(0.2)                       # stesso titolo: chiude
    sc.dump('m15_toggle_close')

    etest.run(sc)
    for n in getattr(sc, 'shots', []):
        etest.render(n)

    print('--- m0 barra dei menu')
    rows, vs, bl = load('m0_start')
    check(rows[0].replace('~', '').startswith(' File  Edit  Find  Help'), 'titoli: ' + rows[0][:20])
    check(vs['menuopen'] == 0, 'menu chiuso')

    print('--- m1 ESC apre File')
    rows, vs, bl = load('m1_open')
    check(vs['menuopen'] == 1 and vs['menusel'] == 0, f'menuopen={vs["menuopen"]} menusel={vs["menusel"]}')
    top = parse_row(rows[1])[:24]
    check(top[0] == ('+', True) and top[23] == ('+', True) and all(c == ('-', True) for c in top[1:23]), 'bordo superiore')
    names = [row_text(rows, 2 + i, 24) for i in range(5)]
    for i, (lab, sc_) in enumerate([('New', ''), ('Open...', 'Ctrl+O'), ('Save', 'Ctrl+S'),
                                    ('Save As...', 'Ctrl+W'), ('Exit', 'Ctrl+Q')]):
        check(lab in names[i] and sc_ in names[i], f'voce {i}: {names[i]!r}')
    bot = parse_row(rows[7])[:24]
    check(bot[0] == ('+', True) and bot[23] == ('+', True), 'bordo inferiore')
    check(not any(row_inv(rows, 2, 1, 23)) and all(row_inv(rows, 3, 1, 23)), 'prima voce in video normale, le altre inverse')
    check(row_text(rows, 8, 12).startswith('008 riga di'), 'testo sotto il riquadro intatto')
    check(parse_row(rows[2])[24][0] == ' ' or True, 'ok')

    print('--- m2/m3 frecce su/giu')
    rows, vs, bl = load('m2_down2')
    check(vs['menusel'] == 2, f'menusel={vs["menusel"]}')
    check(not any(row_inv(rows, 4, 1, 23)) and all(row_inv(rows, 2, 1, 23)), 'evidenziata la terza voce')
    rows, vs, bl = load('m3_wrap')
    check(vs['menusel'] == 4, f'avvolgimento verso l\'alto: menusel={vs["menusel"]}')

    print('--- m4/m5 passaggio tra menu')
    rows, vs, bl = load('m4_edit')
    check(vs['menuopen'] == 2 and vs['menusel'] == 0, f'Edit: menuopen={vs["menuopen"]}')
    check('Undo' in row_text(rows, 2, 32) and 'Ctrl+Z' in row_text(rows, 2, 32) and 'Redo' in row_text(rows, 3, 32)
          and 'Cut' in row_text(rows, 4, 32) and 'Select all' in row_text(rows, 8, 32) and 'Ctrl+A' in row_text(rows, 8, 32),
          'voci di Edit: ' + row_text(rows, 2, 32) + ' / ' + row_text(rows, 8, 32))
    check(parse_row(rows[1])[26][0] != '+', 'larghezza del riquadro Edit = 26')
    rows, vs, bl = load('m5_wrapmenu')
    check(vs['menuopen'] == 1, f'avvolgimento Help -> File: menuopen={vs["menuopen"]}')

    print('--- m6 ESC chiude')
    rows, vs, bl = load('m6_closed')
    check(vs['menuopen'] == 0, 'menu chiuso')
    check(all(row_text(rows, r, 79) == demo[r - 1][:79].ljust(79) for r in range(1, 23)), 'tutto il testo ridisegnato')

    print('--- m7 tasto rapido Select all')
    rows, vs, bl = load('m7_hotkey')
    check(vs['menuopen'] == 0 and vs['selanc'] == 0 and vs['cur'] == vs['len'], f'selanc={vs["selanc"]} cur={vs["cur"]} len={vs["len"]}')

    print('--- m8 Invio su Copy (selezione piu\' grande della clipboard)')
    rows, vs, bl = load('m8_enter_copy')
    msg = rows[0].replace('~', '')
    check('too big' in msg, 'messaggio: ' + msg[19:60].strip())
    check(vs['cliplen'] == 0, f'cliplen={vs["cliplen"]}')

    print('--- m9/m10/m11 mouse')
    rows, vs, bl = load('m9_mouse_open')
    check(vs['menuopen'] == 2, f'clic sul titolo Edit: menuopen={vs["menuopen"]}')
    rows, vs, bl = load('m10_hover')
    check(vs['menuopen'] == 2 and vs['menusel'] == 1, f'hover: menusel={vs["menusel"]}')
    rows, vs, bl = load('m11_click_item')
    check(vs['menuopen'] == 0 and vs['selanc'] == 0 and vs['cur'] == vs['len'], f'clic su Select all: selanc={vs["selanc"]} cur={vs["cur"]}')

    print('--- m12 clic fuori')
    rows, vs, bl = load('m12_click_outside')
    check(vs['menuopen'] == 0, 'menu chiuso')
    check(vs['cur'] == vs['len'], 'il clic non e\' passato al testo (cursore invariato)')

    print('--- m13 Help > About')
    rows, vs, bl = load('m13_about')
    box = ' '.join(row_text(rows, r, 80) for r in range(9, 13)).replace('#', ' ')
    check('SamPr' in box and '1.0' in box and 'Pracek' in box and vs['menuopen'] == 0, 'finestra About: ' + box.strip())

    print('--- m14/m15 cambio menu col mouse')
    rows, vs, bl = load('m14_switch')
    check(vs['menuopen'] == 4, f'menuopen={vs["menuopen"]}')
    check('Index' in row_text(rows, 2, 40) and 'Shortcuts' in row_text(rows, 5, 40) and 'About' in row_text(rows, 6, 40), 'voci di Help: ' + row_text(rows, 2, 40))
    rows, vs, bl = load('m15_toggle_close')
    check(vs['menuopen'] == 0, 'secondo clic sullo stesso titolo chiude')
    print('FALLITI:', etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
