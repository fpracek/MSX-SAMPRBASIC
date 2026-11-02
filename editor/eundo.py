#!/usr/bin/env python3
"""Undo / redo test (ROM build, NMS-8250, 2 KB log): grouped keystrokes, Backspace,
deleting a selection, paste, redo queue discarded by a new edit, global replace
as a single step, full log (the oldest groups are discarded), menu items."""
import sys

import etest
from esel import Model
from esel import parse_row
from esrch import check_view
from etest import Scenario, check, load

CTRL = (6, 0x02)
UNDO = (CTRL, (5, 0x80))
REDO = (CTRL, (5, 0x40))
CTRL_C = (CTRL, (3, 0x01))
CTRL_V = (CTRL, (5, 0x08))
CTRL_T = (CTRL, (5, 0x02))
CTRL_F = (CTRL, (3, 0x08))
ESC = (7, 0x04)
RIGHT = (8, 0x80)
DOWN = (8, 0x40)
HOME = (8, 0x02)
DEL = (8, 0x08)
BS = (7, 0x20)
SELECT = (7, 0x40)


def chord(sc, *keys, gap=0.9):
    sc.do(' '.join(f'keymatrixdown {r} {m};' for r, m in keys) +
          ' after time 0.15 {' + ' '.join(f'keymatrixup {r} {m};' for r, m in keys) + '}', gap)


def shift_tap(sc, key, n):
    sc.do('keymatrixdown 6 1', 0.15)
    sc.tap(key[0], key[1], n, 0.3)
    sc.do('keymatrixup 6 1', 0.2)


def check_view_h(rows, m, vs, label):
    """like check_view but takes the horizontal scroll (hscroll) into account"""
    h, top = vs['hscroll'], vs['topline']
    bad = []
    for r in range(1, 23):
        ln = top + r - 1
        s = m.lines[ln - 1] if ln <= len(m.lines) else ''
        exp = [((s[j] if j < len(s) else ' '), False) for j in range(h, h + 79)]
        if parse_row(rows[r]) != exp:
            bad.append(r)
    check(not bad, f'{label}: righe (da riga {top}, colonna {h}) identiche al modello' + (f' (diverse: {bad[:3]})' if bad else ''))


def msg(rows):
    return rows[0].replace('~', '')[25:80].strip()


def main():
    syms = etest.assemble()
    sc = Scenario(syms)
    base = Model()
    m = Model()
    o = list(base.lines)
    L = lambda name: load(name)[:2]

    def view(name, label, sel=None):
        rows, vs = L(name)
        check_view(rows, m, vs['topline'], sel, label)
        return rows, vs

    # ---- A-C: keystrokes in a single group
    sc.text('Hello', 1.0)
    sc.dump('u1_typed')
    chord(sc, *UNDO)
    sc.dump('u2_undo')
    chord(sc, *REDO)
    sc.dump('u3_redo')
    chord(sc, *UNDO)
    # ---- D: two groups separated by a movement
    sc.text('AB', 0.8)
    sc.tap(*RIGHT, 1, 0.4)
    sc.text('CD', 0.8)
    sc.dump('u4_two_groups')
    chord(sc, *UNDO)
    sc.dump('u5_undo_cd')
    chord(sc, *UNDO)
    sc.dump('u6_undo_ab')
    chord(sc, *REDO)
    chord(sc, *REDO)
    sc.dump('u7_redo_both')
    chord(sc, *UNDO)
    chord(sc, *UNDO)
    # ---- E: Backspace x3 in a single group
    sc.tap(*RIGHT, 5, 0.3)
    sc.tap(*BS, 3, 0.3)
    sc.dump('u8_bs')
    chord(sc, *UNDO)
    sc.dump('u9_undo_bs')
    # ---- F: deleting a selection
    shift_tap(sc, RIGHT, 4)
    sc.tap(*DEL, 1, 0.6)
    sc.dump('u10_seldel')
    chord(sc, *UNDO)
    sc.dump('u11_undo_seldel')
    # ---- G: paste
    sc.tap(*HOME, 1, 0.4)
    shift_tap(sc, RIGHT, 5)
    chord(sc, *CTRL_C)
    sc.tap(*DOWN, 1, 0.4)
    chord(sc, *CTRL_V)
    sc.dump('u12_paste')
    chord(sc, *UNDO)
    sc.dump('u13_undo_paste')
    # ---- H: a new edit discards the redo queue
    sc.text('X', 0.8)
    chord(sc, *UNDO)
    sc.text('Y', 0.8)
    chord(sc, *REDO)
    sc.dump('u14_redo_discarded')
    chord(sc, *UNDO)
    # ---- I: global replace = one step
    chord(sc, *CTRL_T)
    sc.text('riga\\r', 0.8)
    sc.text('ROW\\r', 1.0)
    sc.text('a', 6.0)
    sc.dump('u15_replaced')
    chord(sc, *UNDO, gap=2.0)
    sc.dump('u16_undo_replace')
    chord(sc, *REDO, gap=2.0)
    sc.dump('u17_redo_replace')
    chord(sc, *UNDO, gap=2.0)
    # ---- J: full log: Backspace x300 (8-byte records, capacity 256)
    chord(sc, *CTRL_F)
    sc.tap(*BS, 4, 0.25)                # delete the preloaded 'riga'
    sc.text('009 riga\\r', 1.5)
    sc.tap(*SELECT, 1, 0.6)
    sc.tap(*BS, 300, 0.2)
    sc.wait(1.0)
    sc.dump('u18_bs300')
    chord(sc, *UNDO, gap=2.0)
    sc.dump('u19_undo_overflow')
    chord(sc, *UNDO)
    sc.dump('u20_nothing')
    # ---- K: from the Edit menu
    sc.text('Z', 0.8)
    sc.tap(*ESC, 1, 0.4)
    sc.tap(*RIGHT, 1, 0.4)
    sc.text('u', 1.0)
    sc.dump('u21_menu_undo')
    sc.tap(*ESC, 1, 0.4)
    sc.tap(*RIGHT, 1, 0.4)
    sc.text('r', 1.0)
    sc.dump('u22_menu_redo')

    etest.run(sc)

    # ---------------------------------------------------------- verification
    print('--- u1-u3 battute: un solo passo')
    m.replace((1, 0), (1, 0), 'Hello')
    rows, vs = view('u1_typed', 'u1')
    check(vs['cur'] == 5, f'cur={vs["cur"]}')
    m.replace((1, 0), (1, 5), '')
    rows, vs = view('u2_undo', 'u2 dopo Ctrl+Z')
    check(vs['cur'] == 0 and vs['len'] == base.total() and vs['curline'] == 1, f'cur={vs["cur"]} len={vs["len"]}')
    m.replace((1, 0), (1, 0), 'Hello')
    rows, vs = view('u3_redo', 'u3 dopo Ctrl+Y')
    check(vs['cur'] == 5, f'cur={vs["cur"]}')
    m.replace((1, 0), (1, 5), '')

    print('--- u4-u7 due gruppi')
    m.replace((1, 0), (1, 0), 'AB')
    m.replace((1, 3), (1, 3), 'CD')
    rows, vs = view('u4_two_groups', 'u4')
    check(vs['cur'] == 5, f'cur={vs["cur"]}')
    m.replace((1, 3), (1, 5), '')
    rows, vs = view('u5_undo_cd', 'u5 undo: solo "CD"')
    check(vs['cur'] == 3, f'cur={vs["cur"]}')
    m.replace((1, 0), (1, 2), '')
    rows, vs = view('u6_undo_ab', 'u6 secondo undo: "AB"')
    check(vs['cur'] == 0 and vs['len'] == base.total(), f'cur={vs["cur"]} len={vs["len"]}')
    m.replace((1, 0), (1, 0), 'AB')
    m.replace((1, 3), (1, 3), 'CD')
    rows, vs = view('u7_redo_both', 'u7 due redo')
    check(vs['cur'] == 5, f'cur={vs["cur"]}')
    m.replace((1, 3), (1, 5), '')
    m.replace((1, 0), (1, 2), '')

    print('--- u8/u9 Backspace x3 = un passo')
    m.replace((1, 2), (1, 5), '')
    rows, vs = view('u8_bs', 'u8')
    check(vs['cur'] == 2 and vs['len'] == base.total() - 3, f'cur={vs["cur"]} len={vs["len"]}')
    m.replace((1, 2), (1, 2), o[0][2:5])
    rows, vs = view('u9_undo_bs', 'u9 undo')
    check(vs['cur'] == 5 and vs['len'] == base.total(), f'cur={vs["cur"]} len={vs["len"]}')

    print('--- u10/u11 selezione cancellata')
    m.replace((1, 5), (1, 9), '')
    rows, vs = view('u10_seldel', 'u10')
    check(vs['cur'] == 5 and vs['len'] == base.total() - 4, f'cur={vs["cur"]} len={vs["len"]}')
    m.replace((1, 5), (1, 5), o[0][5:9])
    rows, vs = view('u11_undo_seldel', 'u11 undo')
    check(vs['cur'] == 9 and vs['len'] == base.total(), f'cur={vs["cur"]} len={vs["len"]}')

    print('--- u12/u13 incolla')
    clip = o[0][:5]
    m.replace((2, 5), (2, 5), clip)
    rows, vs = view('u12_paste', 'u12')
    check(vs['cliplen'] == 5 and vs['cur'] == m.off(2, 10), f'cliplen={vs["cliplen"]} cur={vs["cur"]}')
    m.replace((2, 5), (2, 10), '')
    rows, vs = view('u13_undo_paste', 'u13 undo')
    check(vs['cur'] == m.off(2, 5) and vs['len'] == base.total(), f'cur={vs["cur"]} len={vs["len"]}')

    print('--- u14 nuova modifica scarta il redo')
    m.replace((2, 5), (2, 5), 'Y')
    rows, vs = view('u14_redo_discarded', 'u14')
    check('Nothing to redo' in msg(rows), 'messaggio: ' + msg(rows))
    check(vs['cur'] == m.off(2, 6), f'cur={vs["cur"]}')
    m.replace((2, 5), (2, 6), '')

    print('--- u15-u17 sostituzione globale = un passo')
    cur_off = m.off(2, 5)
    count = 0
    repl = Model()
    repl.lines = list(m.lines)
    for ln in range(2, 71):
        s = repl.lines[ln - 1]
        i = s.find('riga')
        if i < 0:
            continue
        if ln == 2 and i < 5:
            continue                       # the match on row 2 starts before the cursor (col 5)
        repl.lines[ln - 1] = s[:i] + 'ROW' + s[i + 4:]
        count += 1
    saved, m.lines = m.lines, repl.lines
    rows, vs = view('u15_replaced', 'u15')
    check(f'Replaced {count} occurrence(s)' == msg(rows), f'messaggio: {msg(rows)!r} (attesi {count})')
    check(vs['len'] == m.total(), f'len={vs["len"]}')
    m.lines = saved
    rows, vs = view('u16_undo_replace', 'u16 un solo Ctrl+Z annulla tutto')
    check(vs['len'] == base.total(), f'len={vs["len"]} (atteso {base.total()})')
    m.lines = repl.lines
    rows, vs = view('u17_redo_replace', 'u17 un solo Ctrl+Y le rifa tutte')
    check(vs['len'] == m.total(), f'len={vs["len"]}')
    m.lines = saved

    print('--- u18-u20 registro pieno')
    c = m.off(9, len(m.lines[8]))
    text = m.text()
    after = text[:c - 300] + text[c:]
    rows, vs = L('u18_bs300')
    check(vs['len'] == len(text) - 300 and vs['cur'] == c - 300, f'len={vs["len"]} (atteso {len(text) - 300}) cur={vs["cur"]}')
    # the last 300-256 = 44 records remain: they bring back 44 characters (the ones farthest from the cursor)
    keep = 300 - 256
    m.lines = (text[:c - 256] + text[c:]).split('\n')
    rows, vs = L('u19_undo_overflow')
    check_view_h(rows, m, vs, 'u19 dopo il registro pieno')
    check(vs['len'] == len(text) - 256 and vs['cur'] == c - 256, f'len={vs["len"]} (atteso {len(text) - 256}) cur={vs["cur"]}; ripristinati {keep}')
    rows, vs = L('u20_nothing')
    check('Nothing to undo' in msg(rows), 'secondo Ctrl+Z: ' + msg(rows))

    print('--- u21/u22 dal menu Edit')
    rows, vs = L('u21_menu_undo')
    check(vs['len'] == len(text) - 256 and vs['menuopen'] == 0, f'dopo Edit>Undo len={vs["len"]} (atteso {len(text) - 256})')
    rows, vs = L('u22_menu_redo')
    check(vs['len'] == len(text) - 255 and vs['menuopen'] == 0, f'dopo Edit>Redo len={vs["len"]} (atteso {len(text) - 255})')
    print('FALLITI:', etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
