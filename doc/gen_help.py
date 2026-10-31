# -*- coding: utf-8 -*-
"""Genera HELP.TXT e HELP.IDX per l'aiuto dell'editor. uso: python gen_help.py [cartella_uscita ...]"""
import os
import re
import sys
import textwrap

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import topics_core
import topics_hw
import topics_guide  # noqa: F401
from topics_core import TOPICS

W = 38
MAXIDX = 3700 // 17
ACC = {'à': "a'", 'è': "e'", 'é': "e'", 'ì': "i'", 'ò': "o'", 'ù': "u'", 'È': "E'", 'À': "A'", '’': "'", '–': '-', '—': '-', '«': '"', '»': '"', 'ü': 'u'}


def asc(s):
    s = s.replace('`', '')
    for k, v in ACC.items():
        s = s.replace(k, v)
    return s.encode('ascii', 'replace').decode('ascii')


def body(t):
    out = []
    name = t['names'][0]
    out.append(asc(name))
    out.append('-' * min(len(asc(name)), W))
    out.append('')
    for s in t['syn']:
        out += textwrap.wrap(asc(s), W, subsequent_indent='    ') or ['']
    out.append('')
    out += textwrap.wrap(asc(t['desc']), W)
    if t['ex']:
        out += ['', 'Esempio:']
        for l in t['ex'].split('\n'):
            out += textwrap.wrap(asc(l), W, initial_indent='  ', subsequent_indent='    ', drop_whitespace=False) or ['']
    if t['avail'] != 'MSX1 e MSX2':
        out += [''] + textwrap.wrap(asc('Disponibile: ' + t['avail']), W)
    if t['see']:
        out += textwrap.wrap('Vedi anche: ' + ', '.join(asc(x) for x in t['see']), W)
    return out


def build():
    texts = []
    cats = []
    for t in TOPICS:
        if t['cat'] not in cats:
            cats.append(t['cat'])
    # indice
    idx_lines = ['INDICE DEGLI ARGOMENTI', '', 'Scrivi il nome in Help > Topic, oppure', 'F6 sulla parola sotto il cursore.', '']
    for c in cats:
        idx_lines.append(asc(c.upper()))
        names = [asc(t['names'][0]) for t in TOPICS if t['cat'] == c and len(t['names'][0]) <= 12]
        line = ''
        for n in names:
            cell = n.ljust(13)
            if len(line) + len(cell) > W:
                idx_lines.append(line.rstrip())
                line = ''
            line += cell
        if line:
            idx_lines.append(line.rstrip())
        idx_lines.append('')
    entries = [('INDEX', idx_lines)]
    seen = {'INDEX'}
    alias = []
    for t in TOPICS:
        b = body(t)
        prim = asc(t['names'][0]).upper()
        if len(prim) > 12:
            prim = prim[:12]
        first = None
        for n in t['names']:
            nn = asc(n).upper()
            if len(nn) > 12 or nn in seen:
                continue
            if first is None:
                first = nn
                entries.append((nn, b))
            else:
                alias.append((nn, first))
            seen.add(nn)
        if first is None:
            print('ATTENZIONE: nessun nome utilizzabile per', t['names'])
    alias_map = dict(alias)
    data = b''
    pos = {}
    for nn, lines in entries:
        raw = ('\r\n'.join(lines) + '\r\n').encode('ascii')
        assert len(raw) <= 4000, (nn, len(raw))
        assert all(len(l) <= W for l in lines), (nn, [l for l in lines if len(l) > W])
        pos[nn] = (len(data), len(raw))
        data += raw
    recs = []
    for nn, _ in entries:
        recs.append((nn, pos[nn]))
    for nn, f in alias:
        recs.append((nn, pos[f]))
    if len(recs) > MAXIDX:
        print('ATTENZIONE: indice troppo grande, taglio', len(recs) - MAXIDX, 'alias')
        recs = recs[:MAXIDX]
    recs.sort(key=lambda r: r[0])
    idx = b''
    for nn, (off, ln) in recs:
        idx += nn.encode('ascii').ljust(12, b'\0') + off.to_bytes(3, 'little') + ln.to_bytes(2, 'little')
    idx += b'\0'
    return data, idx, len(recs)


if __name__ == '__main__':
    data, idx, n = build()
    outs = sys.argv[1:] or [os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')]
    for o in outs:
        os.makedirs(o, exist_ok=True)
        open(os.path.join(o, 'HELP.TXT'), 'wb').write(data)
        open(os.path.join(o, 'HELP.IDX'), 'wb').write(idx)
    print('HELP.TXT %d byte, HELP.IDX %d byte (%d voci)' % (len(data), len(idx), n))
