#!/usr/bin/env python3
"""Extracts the comments of the assembler sources (.asm/.inc) that look Italian into a JSON list, and applies translations back.
usage: cm_extract.py extract OUT.json | apply TRANSLATED.json"""
import json, os, re, sys

BS = chr(92)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STRONG = re.compile(r"[àèéìòù]|\b(il|lo|gli|della|dello|nella|nel|dei|delle|per|che|con|non|sono|viene|dopo|prima|sulla|alla|dalla|tutti|ogni|oppure|quando|anche|come|solo|stesso|riga|chiama|serve|puo|invece|sempre|dentro|fuori|senza|resta|torna|scrive|legge|azzera|imposta|controlla|ritorna|errore|vuota|salto|fine|inizio|puntatore|primo|ultimo|numero|lunghezza|carica|salva|copia|attende|lascia|evita|usa|attivo|byte|riga|righe|dati|testo|tasto|schermo|cursore|nome|memoria|valore)\b", re.I)
SKIP_DIRS = {'.git', 'node_modules', 'build', 'dist', 'out', 'img', 'samples', 'tools', 'shots', '.vscode-test', 'vscode', 'demo'}


def split_comment(line):
    """-> (index of the ';' that starts the comment or -1)"""
    q = None
    i = 0
    while i < len(line):
        ch = line[i]
        if q:
            if ch == q:
                q = None
        elif ch == '"':
            q = ch
        elif ch == "'":
            j = line.find("'", i + 1)
            if j != -1 and j - i <= 3:
                i = j                      # 'x' character constant, or AF'
            else:
                q = ch
        elif ch == ';':
            return i
        i += 1
    return -1


def files():
    out = []
    for root, dirs, fs in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in fs:
            if f.lower().endswith(('.asm', '.inc')):
                out.append(os.path.join(root, f))
    return sorted(out)


def read(p):
    raw = open(p, 'rb').read()
    try:
        return raw.decode('utf-8'), 'utf-8'
    except UnicodeDecodeError:
        return raw.decode('latin1'), 'latin1'


def extract(outp):
    items = []
    for p in files():
        t, _ = read(p)
        for n, l in enumerate(t.replace('\r\n', '\n').split('\n')):
            i = split_comment(l)
            if i < 0:
                continue
            c = l[i + 1:].strip()
            if len(c) >= 3 and STRONG.search(c):
                items.append({'f': os.path.relpath(p, ROOT).replace(BS, '/'), 'l': n + 1, 't': c})
    json.dump(items, open(outp, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    print(len(items), 'comments in', len({i['f'] for i in items}), 'files')


def apply(inp):
    items = json.load(open(inp, encoding='utf-8'))
    by = {}
    for it in items:
        by.setdefault(it['f'], {})[it['l']] = it
    changed = 0
    for f, d in by.items():
        p = os.path.join(ROOT, f)
        raw = open(p, 'rb').read()
        crlf = b'\r\n' in raw
        t, enc = read(p)
        lines = t.replace('\r\n', '\n').split('\n')
        for ln, it in d.items():
            if 'e' not in it:
                continue
            l = lines[ln - 1]
            i = split_comment(l)
            if i < 0 or l[i + 1:].strip() != it['t']:
                print('MISMATCH', f, ln)
                continue
            new = it['e'].strip()
            lead = l[i + 1:][:len(l[i + 1:]) - len(l[i + 1:].lstrip())]
            lines[ln - 1] = l[:i + 1] + (lead if lead else ' ') + new
            changed += 1
        txt = '\n'.join(lines)
        if crlf:
            txt = txt.replace('\n', '\r\n')
        open(p, 'wb').write(txt.encode(enc))
    print('changed', changed)


if __name__ == '__main__':
    if sys.argv[1] == 'extract':
        extract(sys.argv[2])
    else:
        apply(sys.argv[2])
