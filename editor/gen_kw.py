#!/usr/bin/env python3
"""Genera kwtab.inc (parole chiave BASIC per l'evidenziazione) dalle tabelle del compilatore ../onmsx/qbc.asm."""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, '..', 'onmsx', 'qbc.asm'), encoding='latin-1').read()
words = set()
for name in ('kwtab:', 'bitab:'):
    i = src.index(name)
    j = src.index('\n\n', i) if '\n\n' in src[i:i + 3000] else i + 1500
    block = src[i:j]
    # solo le righe della tabella (db "...",0,...)
    for line in block.split('\n'):
        if name in line or line.strip().startswith('db'):
            for w in re.findall(r'"([A-Z$]+)"', line):
                words.add(w)
        else:
            break
words |= {'REM', '__ASM', '__ENDASM', 'DEBUG', 'NUMBERED', 'LABELS', 'MIXED', 'TARGET', 'FAR', 'MAPPER', 'RANDOM', 'OUTPUT',
          'APPEND', 'AS', 'INPUT', 'ROM16', 'ROM32', 'ASCII8', 'ASCII16', 'KONAMI', 'SCC', 'COM', 'BF', 'SPRITE$', 'TIMER'}
words = sorted(w for w in words if len(w) <= 16)
groups = {}
for w in words:
    k = 26 if w[0] == '_' else ord(w[0]) - 65
    if 0 <= k <= 26:
        groups.setdefault(k, []).append(w)
out = ['; generato da gen_kw.py: parole chiave BASIC (%d), indice per iniziale (A-Z, _) e lunghezza (2-10)' % len(words), 'kwidx:']
for k in range(27):
    out.append('        dw ' + ','.join(('kwl%d_%d' % (k, n)) if any(len(w) == n for w in groups.get(k, [])) else 'kwempty' for n in range(2, 11)))
out.append('kwempty: db 0')
for k in range(27):
    for n in range(2, 11):
        ws = [w for w in groups.get(k, []) if len(w) == n]
        if ws:
            out.append('kwl%d_%d:' % (k, n))
            for w in ws:
                out.append('        db "%s"' % w)
            out.append('        db 0')
out.append('        ALIGN 256')
out.append('kwcls:')
for r in range(16):
    row = []
    for c in range(16):
        ch = (r * 16 + c) & 127
        ci = chr(ch)
        if ci == '"':
            v = 2
        elif ci == "'":
            v = 3
        elif ch == 0 and (r * 16 + c) < 128:
            v = 4
        elif ci.isalnum() and ch < 128 or ci in '_$':
            v = 1
        else:
            v = 0
        row.append(str(v))
    out.append('        db ' + ','.join(row))
open(os.path.join(HERE, 'kwtab.inc'), 'w', newline='\n').write('\n'.join(out) + '\n')
print(len(words), 'parole')
