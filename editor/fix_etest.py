p = 'etest.py'
t = open(p, encoding='utf-8', newline='').read()
nl = '\r\n' if '\r\n' in t else '\n'
t = t.replace('\r\n', '\n')


def rep(a, b):
    global t
    assert t.count(a) == 1, (a[:60], t.count(a))
    t = t.replace(a, b)


rep("'selanc', 'cliplen', 'menuopen', 'menusel', 'mcase']", "'selanc', 'cliplen', 'menuopen', 'menusel', 'mcase', 'blx', 'bly', 'curch', 'cph']")
# dump: il cursore e' un glifo inverso: si rimette il carattere originale e si riporta la cella a parte
rep("""    binary scan $data c* bytes
    set row ""; set n 0; set r 0""", """    binary scan $data c* bytes
    set cbx [debug read memory [dict get $VARADDR blx]]
    set cby [debug read memory [dict get $VARADDR bly]]
    if {$cbx != 255} {
        set cch [debug read memory [dict get $VARADDR curch]]
        lset bytes [expr {$cby * 80 + $cbx}] $cch
        puts $f "CURSOR $cby $cbx"
    }
    set row ""; set n 0; set r 0""")
rep("""        elif p[0] == 'BLINK':
            q = ln.split()
            bl.append((int(q[1]), int(q[2]), int(q[3])))""", """        elif p[0] == 'CURSOR':
            q = ln.split()
            r_, c_ = int(q[1]), int(q[2])
            bl.append((r_, (c_ // 8) * 8, 0x80 >> (c_ % 8)))""")
rep("""            blink = v[0x800 + r * 10 + (c >> 3)] & (0x80 >> (c & 7))
            pat = v[0x1000 + ch * 8: 0x1000 + ch * 8 + 8]
            for y in range(8):
                for x in range(6):
                    on = bool(pat[y] & (0x80 >> x)) != bool(blink)
                    px[c * 6 + x, r * 8 + y] = FG if on else BG""", """            alt = v[0x800 + r * 10 + (c >> 3)] & (0x80 >> (c & 7))
            pat = v[0x1000 + ch * 8: 0x1000 + ch * 8 + 8]
            for y in range(8):
                for x in range(6):
                    on = bool(pat[y] & (0x80 >> x))
                    px[c * 6 + x, r * 8 + y] = (KW if alt else FG) if on else BG""")
rep("    FG, BG = (255, 255, 255), (36, 36, 170)", "    FG, BG, KW = (255, 255, 255), (36, 36, 170), (255, 255, 120)")
open(p, 'w', encoding='utf-8', newline='').write(t.replace('\n', nl))
print('ok')
