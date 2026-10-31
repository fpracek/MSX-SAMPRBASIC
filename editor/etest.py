#!/usr/bin/env python3
"""Test headless dell'editor: assembla (con testo demo), esegue in openMSX (NMS-8250)
una sequenza temporizzata di tasti / eventi mouse simulati e verifica schermo e variabili.

uso: python etest.py [--shots]
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SJASM = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\sjasmplus-1.20.3.win\sjasmplus.exe'
OPENMSX = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe'
MACHINE = 'Philips_NMS_8250'
BUILD = os.path.join(HERE, 'build')

VARS = ['cur', 'len', 'gs', 'gsz', 'top', 'topline', 'curline', 'nlines', 'hscroll',
        'wantcol', 'mpx', 'mpy', 'mcx', 'mcy', 'mdrag', 'mshown', 'mmode', 'selanc', 'cliplen', 'menuopen', 'menusel', 'mcase', 'blx', 'bly', 'curch', 'cph', 'curdr']


def demo_lines():
    out = []
    for i in range(1, 71):
        if i % 7 == 0:
            body = ('0123456789' * 25)[:200 - 4]
        else:
            body = f'riga di prova numero {i} - testo qualunque per provare lo scroll'
        out.append(f'{i:03d} ' + body)
    return out


def assemble():
    os.makedirs(BUILD, exist_ok=True)
    open(os.path.join(HERE, 'demo.txt'), 'w', newline='\n').write('\n'.join(demo_lines()) + '\n')
    r = subprocess.run([SJASM, '-DDEMO', f'--inc={HERE}', f'--sym={BUILD}\\editor.sym', 'editor.asm'],
                       cwd=HERE, capture_output=True, text=True)
    print(r.stdout.strip().split('\n')[-1])
    if r.returncode != 0 or 'error:' in (r.stdout + r.stderr).lower():
        print(r.stdout, r.stderr)
        sys.exit(2)
    os.replace(os.path.join(HERE, 'editor.rom'), os.path.join(BUILD, 'editor.rom'))
    syms = {}
    for ln in open(os.path.join(BUILD, 'editor.sym')):
        m = re.match(r'^(\w+): EQU 0x([0-9A-Fa-f]+)', ln)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return syms


PRELUDE = r'''
set throttle off
catch {set renderer none}      ;# nessuna finestra: niente tasti veri dalla tastiera del PC
proc poke8 {a v} { debug write memory $a $v }
proc poke16 {a v} { debug write memory $a [expr {$v & 255}]; debug write memory [expr {$a+1}] [expr {($v>>8)&255}] }
proc peek16 {a} { expr {[debug read memory $a] + 256*[debug read memory [expr {$a+1}]]} }
proc keytap {row mask} { keymatrixdown $row $mask; after time 0.12 [list keymatrixup $row $mask] }
proc dump {name} {
    global VARADDR OUTDIR
    set f [open "$OUTDIR/$name.txt" w]
    set data [debug read_block VRAM 0 1920]
    binary scan $data c* bytes
    set cbx [debug read memory [dict get $VARADDR blx]]
    set cby [debug read memory [dict get $VARADDR bly]]
    if {$cbx < 80 && $cby < 24 && ![info exists ::nopatch]} {
        if {[debug read memory [dict get $VARADDR curdr]] != 0} {
            set cch [debug read memory [dict get $VARADDR curch]]
            lset bytes [expr {$cby * 80 + $cbx}] $cch
        }
        puts $f "CURSOR $cby $cbx"
    }
    set row ""; set n 0; set r 0
    foreach b $bytes {
        set b [expr {$b & 255}]
        if {$r == 0} { set b [expr {$b & 127}] }
        if {$b == 160} { set c "#" } elseif {$b == 1} { set c "^" } elseif {$b == 2} { set c "v" } \
        elseif {$b == 3} { set c "<" } elseif {$b == 4} { set c ">" } elseif {$b == 5} { set c ":" } \
        elseif {($b & 127) in {6 7 8 9 11 12}} { set c [dict get {6 - 7 | 8 + 9 + 11 + 12 +} [expr {$b & 127}]]; if {$b >= 128} { set c "~$c" } } \
        elseif {$b >= 128 && ($b & 127) >= 32 && ($b & 127) < 127} { set c [format %c [expr {$b & 127}]]; set c "~$c" } \
        elseif {$b >= 32 && $b < 127} { set c [format %c $b] } else { set c "?" }
        append row $c
        incr n
        if {$n == 80} { puts $f "ROW $r $row"; set row ""; set n 0; incr r }
    }
    foreach {k a} $VARADDR {
        if {$k in {cur len gs gsz top topline curline nlines hscroll wantcol mpx mpy selanc cliplen}} { puts $f "VAR $k [peek16 $a]" } \
        else { puts $f "VAR $k [debug read memory $a]" }
    }
    set vr [debug read_block VRAM 0 6144]
    set g [open "$OUTDIR/$name.vram" wb]
    puts -nonewline $g $vr
    close $g
    set bl [debug read_block VRAM 2048 240]
    binary scan $bl c* bb
    set i 0
    foreach b $bb {
        set b [expr {$b & 255}]
        if {$b} { puts $f "BLINK [expr {$i / 10}] [expr {($i % 10) * 8}] $b" }
        incr i
    }
    close $f
}
'''


class Scenario:
    def __init__(self, syms):
        self.syms = syms
        self.steps = []
        self.t = 12.0                  # secondi emulati: tempo per il boot

    def wait(self, s):
        self.t += s

    def do(self, tcl, wait=0.3):
        self.steps.append((self.t, tcl))
        self.t += wait

    def tap(self, row, mask, n=1, gap=0.25):
        for _ in range(n):
            self.do(f'keytap {row} {mask}', gap)

    def text(self, s, gap=0.6):
        self.do('type "%s"' % s, gap)

    def poke8(self, name, v, wait=0.1):
        self.do(f'poke8 {self.syms[name]} {v}', wait)

    def poke16(self, name, v, wait=0.1):
        self.do(f'poke16 {self.syms[name]} {v}', wait)

    def pointer(self, cx, cy):
        """posiziona il puntatore al centro della cella (cx, cy)"""
        self.poke16('mpx', cx * 8 + 3, 0.0)
        self.poke16('mpy', cy * 8 + 3, 0.1)

    def click(self, hold=0.25):
        self.poke8('tm_btn', 1, hold)
        self.poke8('tm_btn', 0, 0.2)

    def dump(self, name, shot=False):
        self.wait(0.8)
        self.do('dump %s' % name, 0.1)
        if shot:
            self.shots = getattr(self, 'shots', []) + [name]

    def script(self):
        lines = [PRELUDE, 'set OUTDIR "%s"' % BUILD.replace('\\', '/'),
                 'set VARADDR {%s}' % ' '.join(f'{v} {self.syms[v]}' for v in VARS)]
        for t, tcl in self.steps:
            lines.append('after time %.3f {%s}' % (t, tcl))
        lines.append('after time %.3f exit' % (self.t + 0.5))
        return '\n'.join(lines)


def run(sc):
    tcl = os.path.join(BUILD, 'editor.tcl')
    open(tcl, 'w').write(sc.script())
    for f in os.listdir(BUILD):
        if f.endswith(('.txt', '.vram', '.png')):          # nessun dump vecchio deve poter essere riletto
            os.remove(os.path.join(BUILD, f))
    subprocess.run([OPENMSX, '-machine', MACHINE, '-carta', os.path.join(BUILD, 'editor.rom'),
                    '-script', tcl], timeout=300)


def render(name):
    """ricostruisce lo schermo (SCREEN 0 W80, 6x8 px, blink = inverso) dalla VRAM salvata"""
    from PIL import Image
    v = open(os.path.join(BUILD, name + '.vram'), 'rb').read()
    FG, BG, KW = (255, 255, 255), (36, 36, 170), (255, 255, 120)
    img = Image.new('RGB', (480, 192), BG)
    px = img.load()
    for r in range(24):
        for c in range(80):
            ch = v[r * 80 + c]
            alt = v[0x800 + r * 10 + (c >> 3)] & (0x80 >> (c & 7))
            pat = v[0x1000 + ch * 8: 0x1000 + ch * 8 + 8]
            for y in range(8):
                for x in range(6):
                    on = bool(pat[y] & (0x80 >> x))
                    px[c * 6 + x, r * 8 + y] = (KW if alt else FG) if on else BG
    img.resize((960, 384), Image.NEAREST).save(os.path.join(BUILD, name + '.png'))


def load(name):
    rows, vs, bl = {}, {}, []
    for ln in open(os.path.join(BUILD, name + '.txt'), encoding='latin-1'):
        p = ln.rstrip('\n').split(' ', 2)
        if p[0] == 'ROW':
            rows[int(p[1])] = p[2]
        elif p[0] == 'VAR':
            vs[p[1]] = int(p[2])
        elif p[0] == 'CURSOR':
            q = ln.split()
            r_, c_ = int(q[1]), int(q[2])
            bl.append((r_, (c_ // 8) * 8, 0x80 >> (c_ % 8)))
    return rows, vs, bl


HMAX = 176
FAILS = 0


def check(cond, msg):
    global FAILS
    print(('  ok   ' if cond else '  FAIL ') + msg)
    if not cond:
        FAILS += 1


def blink_cell(bl):
    """(riga, colonna) della cella con il bit di blink acceso"""
    for r, c0, b in bl:
        for k in range(8):
            if b & (0x80 >> k):
                return r, c0 + k
    return None


def main():
    shots = '--shots' in sys.argv
    syms = assemble()
    demo = demo_lines()
    sc = Scenario(syms)

    sc.dump('s1_init', shots)
    # --- tastiera: giu x3, destra x5, scrivo, invio, scrivo
    sc.tap(8, 0x40, 3)
    sc.tap(8, 0x80, 5)
    sc.text('XY')
    sc.dump('s2_edit', shots)
    sc.tap(7, 0x80, 1)               # Enter
    sc.text('Z')
    sc.tap(7, 0x20, 2)               # Backspace x2 (cancella Z e l'a-capo)
    sc.dump('s3_enter_bs')
    # --- scroll verticale con la tastiera: giu x30
    sc.tap(8, 0x40, 30, 0.2)
    sc.dump('s4_scrollv', shots)
    # --- scroll orizzontale: vai sulla riga 7 (lunga) e premi End
    sc.tap(8, 0x20, 30, 0.2)           # su x30
    sc.tap(8, 0x40, 3, 0.25)           # giu x3
    sc.tap(7, 0x40, 1)                 # SELECT = End
    sc.dump('s5_end', shots)
    sc.tap(8, 0x02, 1)                 # Home
    sc.dump('s5b_home')
    # --- mouse (modo test)
    sc.poke8('mmode', 1)
    sc.pointer(79, 22)
    sc.click(0.15)                     # freccia giu' una volta
    sc.dump('s6_down', shots)
    sc.pointer(79, 21)
    sc.click(0.15)                     # binario sotto il pollice? (pollice in alto) -> pagina giu'
    sc.dump('s7_pgdn')
    sc.pointer(79, 1)
    sc.click(0.15)                     # freccia su
    sc.dump('s8_up')
    # trascina il pollice verticale: premi sul pollice e spostalo
    sc.pointer(79, 8)                  # dopo s8 topline=25 -> pollice a riga 2+(24*19)//70 = 8
    sc.poke8('tm_btn', 1, 0.3)         # premo e tengo premuto sul pollice
    sc.poke16('mpy', 14 * 8 + 3, 0.5)  # trascino il puntatore alla riga 14
    sc.dump('s9_drag')
    sc.poke8('tm_btn', 0, 0.3)
    sc.poke16('mpy', 2 * 8 + 3, 0.3)   # a pulsante rilasciato il pollice non deve seguire
    sc.dump('s9b_released')
    # orizzontale
    sc.pointer(78, 23)
    sc.click(0.15)
    sc.dump('s10_hright', shots)
    sc.pointer(70, 23)
    sc.click(0.15)
    sc.dump('s11_hpg')
    sc.pointer(0, 23)
    sc.click(0.15)
    sc.dump('s12_hleft')
    sc.pointer(1, 23)                  # pagina a sinistra: hscroll 78 -> 0, il pollice torna alla colonna 1
    sc.click(0.15)
    sc.dump('s12a_hhome')
    sc.poke8('tm_btn', 1, 0.3)
    sc.poke16('mpx', 40 * 8 + 3, 0.5)
    sc.dump('s12b_hdrag', shots)
    sc.poke8('tm_btn', 0, 0.3)
    # clic nel testo
    sc.pointer(12, 6)
    sc.click(0.15)
    sc.dump('s13_click', shots)
    run(sc)
    for n in getattr(sc, 'shots', []):
        render(n)

    print('--- s1 iniziale')
    rows, vs, bl = load('s1_init')
    check(rows[0].replace('~', '').startswith(' File  Edit  Find  Help'), 'barra dei menu: ' + rows[0][:20])
    check('Ln 1/71  Col 1' in rows[0].replace('~', ''), 'status Ln 1/71 Col 1: ' + rows[0].replace('~', '')[40:])
    check(vs['nlines'] == 71 and vs['curline'] == 1 and vs['topline'] == 1, f'vars {vs["nlines"]},{vs["curline"]},{vs["topline"]}')
    for r in (1, 2, 7, 22):
        check(rows[r][:79] == demo[r - 1][:79].ljust(79), f'riga {r} = demo[{r - 1}]')
    check(rows[1][79] == '^' and rows[22][79] == 'v', 'frecce verticali')
    check(rows[2][79] == '#', 'pollice verticale in cima')
    check(rows[23][0] == '<' and rows[23][78] == '>' and rows[23][1] == '#', 'barra orizzontale')
    check(blink_cell(bl) == (1, 0), f'cursore blink in {blink_cell(bl)}')

    print('--- s2 modifica')
    rows, vs, bl = load('s2_edit')
    check(vs['curline'] == 4 and vs['cur'] == len('\n'.join(demo[:3])) + 1 + 5 + 2, f'cursore curline={vs["curline"]} cur={vs["cur"]}')
    exp = demo[3][:5] + 'XY' + demo[3][5:]
    check(rows[4][:79] == exp[:79].ljust(79), 'riga 4 con XY inserito: ' + rows[4][:20])
    check(blink_cell(bl) == (4, 7), f'blink in {blink_cell(bl)}')
    check('Ln 4/71  Col 8' in rows[0].replace('~', ''), 'status dopo la digitazione: ' + rows[0].replace('~', '')[40:])

    print('--- s3 invio / backspace')
    rows, vs, bl = load('s3_enter_bs')
    check(vs['nlines'] == 71 and vs['curline'] == 4, f'nlines={vs["nlines"]} curline={vs["curline"]}')
    check(rows[4][:79] == exp[:79].ljust(79), 'testo ripristinato dopo Enter+Z+BS+BS')

    print('--- s4 scroll verticale da tastiera')
    rows, vs, bl = load('s4_scrollv')
    check(vs['curline'] == 34 and vs['topline'] == 34 - 21, f'curline={vs["curline"]} topline={vs["topline"]}')
    check(rows[22].startswith(f'{34:03d} '), 'ultima riga visibile = 034')
    check(rows[1].startswith(f'{13:03d} '), 'prima riga visibile = 013')
    check(blink_cell(bl)[0] == 22, f'cursore sull\'ultima riga {blink_cell(bl)}')
    ti = [i for i in range(2, 22) if rows[i][79] == '#']
    check(len(ti) == 1 and ti[0] > 2, f'pollice spostato: righe {ti}')

    print('--- s5 End su riga lunga -> scroll orizzontale')
    rows, vs, bl = load('s5_end')
    check(vs['curline'] == 7 + 0 or vs['curline'] == 7, f'curline={vs["curline"]}')
    check(vs['hscroll'] > 0, f'hscroll={vs["hscroll"]}')
    check(blink_cell(bl) is not None and blink_cell(bl)[1] == 78, f'cursore alla colonna 78: {blink_cell(bl)}')
    hs = [i for i in range(1, 78) if rows[23][i] == '#']
    check(len(hs) == 1 and hs[0] > 1, f'pollice orizzontale spostato: {hs}')
    rows, vs, bl = load('s5b_home')
    check(vs['hscroll'] == 0, f'dopo Home hscroll={vs["hscroll"]}')

    print('--- s6 mouse: frecce e binari')
    rows, vs, bl = load('s6_down')
    check(vs['mmode'] == 1, 'modo test mouse attivo')
    topline0 = load('s5b_home')[1]['topline']
    check(vs['topline'] == topline0 + 1, f'freccia giu: topline {topline0} -> {vs["topline"]}')
    t6 = vs['topline']
    rows, vs, bl = load('s7_pgdn')
    check(vs['topline'] > t6 + 5, f'pagina giu: topline {t6} -> {vs["topline"]}')
    t7 = vs['topline']
    rows, vs, bl = load('s8_up')
    check(vs['topline'] == t7 - 1, f'freccia su: {t7} -> {vs["topline"]}')
    rows, vs, bl = load('s9_drag')
    exp_top = 1 + -(-(12 * 70) // 19)
    check(vs['topline'] == exp_top, f'trascinamento pollice V: topline={vs["topline"]} (atteso {exp_top})')
    check(vs['mdrag'] == 1, 'mdrag=1 durante il trascinamento')
    ti = [i for i in range(2, 22) if rows[i][79] in '# ']   # il puntatore (XOR) sul pollice lo fa sembrare uno spazio
    check(ti == [14], f'pollice disegnato alla riga 14: {ti}')
    rows, vs, bl = load('s9b_released')
    check(vs['topline'] == exp_top and vs['mdrag'] == 0, f'rilascio: topline={vs["topline"]} mdrag={vs["mdrag"]}')
    print('--- s10-12 barra orizzontale')
    rows, vs, bl = load('s10_hright')
    check(vs['hscroll'] == 1, f'freccia destra: hscroll={vs["hscroll"]}')
    rows, vs, bl = load('s11_hpg')
    check(vs['hscroll'] > 40, f'pagina a destra: hscroll={vs["hscroll"]}')
    rows, vs, bl = load('s12_hleft')
    check(vs['hscroll'] == 78, f'freccia sinistra: hscroll={vs["hscroll"]}')
    rows, vs, bl = load('s12b_hdrag')
    exp_h = -(-(39 * HMAX) // 76)
    check(vs['hscroll'] == exp_h, f'trascinamento pollice H: hscroll={vs["hscroll"]} (atteso {exp_h})')
    hs = [i for i in range(1, 78) if rows[23][i] in '# ']
    check(hs == [40], f'pollice orizzontale alla colonna 40: {hs}')
    print('--- s13 clic nel testo')
    rows, vs, bl = load('s13_click')
    check(vs['curline'] == vs['topline'] + 5, f'curline={vs["curline"]} topline={vs["topline"]}')
    print('FALLITI:', FAILS)
    sys.exit(1 if FAILS else 0)


if __name__ == '__main__':
    main()



