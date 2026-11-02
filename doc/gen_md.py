# -*- coding: utf-8 -*-
"""Builds the Markdown version of the manual (doc/MANUAL.md) from the same sources as the PDF and the on-MSX help:
chapters.py (narrative) and topics_*.py (language reference).  usage: python gen_md.py [output.md]"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import topics_core
import topics_hw
import topics_guide  # noqa: F401
from chapters import CHAPTERS
from topics_core import TOPICS

VERSION = 'SamPr Basic 1.0'


def inline(s):
    """the small HTML subset used by chapters.py -> Markdown"""
    s = re.sub(r"<font face='Courier'[^>]*>(.*?)</font>", lambda m: '`' + m.group(1) + '`', s, flags=re.S)
    s = re.sub(r'<b>(.*?)</b>', r'**\1**', s, flags=re.S)
    s = re.sub(r'<i>(.*?)</i>', r'*\1*', s, flags=re.S)
    s = re.sub(r'<br\s*/?>', '  \n', s)
    s = re.sub(r'<[^>]+>', '', s)
    return s.replace('&gt;', '>').replace('&lt;', '<').replace('&amp;', '&')


def cell(s):
    return inline(s).replace('|', '\\|').replace('\n', ' ')


def table(rows):
    out = ['| ' + ' | '.join(cell(c) for c in rows[0]) + ' |', '|' + '---|' * len(rows[0])]
    for r in rows[1:]:
        out.append('| ' + ' | '.join(cell(c) for c in r) + ' |')
    return '\n'.join(out) + '\n'


def blocks(bl):
    out = []
    for b in bl:
        k = b[0]
        if k == 'p':
            out.append(inline(b[1]) + '\n')
        elif k == 'h':
            out.append('### ' + inline(b[1]) + '\n')
        elif k == 'code':
            out.append('```basic\n' + b[1].strip('\n') + '\n```\n')
        elif k == 'ul':
            out.append('\n'.join('- ' + inline(x) for x in b[1]) + '\n')
        elif k == 'table':
            out.append(table(b[1]))
        elif k == 'img':
            out.append('![%s](img/%s)\n' % (inline(b[2]), b[1]))
    return '\n'.join(out)


_seen = {}


def anchor(title):
    a = re.sub(r'[^a-z0-9 -]', '', title.lower()).strip().replace(' ', '-')
    n = _seen.get(a, 0)
    _seen[a] = n + 1
    return a if n == 0 else '%s-%d' % (a, n)    # GitHub numbers repeated headings


def topic(t):
    out = ['### ' + t['names'][0] + '\n']
    if len(t['names']) > 1:
        out.append('*Also:* ' + ', '.join('`%s`' % n for n in t['names'][1:]) + '\n')
    out.append('```\n' + '\n'.join(t['syn']) + '\n```\n')
    out.append(t['desc'] + '\n')
    if t['avail'] != 'MSX1 and MSX2':
        out.append('**Availability:** ' + t['avail'] + '\n')
    if t['ex']:
        out.append('Example:\n\n```basic\n' + t['ex'] + '\n```\n')
    if t['see']:
        out.append('See also: ' + ', '.join('`%s`' % x for x in t['see']) + '\n')
    return '\n'.join(out)


def build(fn):
    o = []
    o.append('# %s - User manual and reference\n' % VERSION)
    o.append('> This file is generated from the same sources as the PDF manual and the on-MSX help '
             '(`doc/chapters.py`, `doc/topics_core.py`, `doc/topics_hw.py`, `doc/topics_guide.py`) with `python doc/gen_md.py`. '
             'Corrections and improvements are welcome as pull requests or issues: please edit those source files (the text is plain Python strings) '
             'or send the change on this file and it will be ported.\n')
    main = [c for c in CHAPTERS if c[0] != 'Errors and limits']
    last = [c for c in CHAPTERS if c[0] == 'Errors and limits']
    cats = []
    for t in TOPICS:
        if t['cat'] not in cats and t['cat'] != 'Guide':
            cats.append(t['cat'])
    o.append('## Contents\n')
    for title, _ in main:
        o.append('- [%s](#%s)' % (title, anchor(title)))
    o.append('- [Language reference](#language-reference)')
    for c in cats:
        o.append('  - [%s](#%s)' % (c, anchor(c)))
    for title, _ in last:
        o.append('- [%s](#%s)' % (title, anchor(title)))
    o.append('- [Keyword index](#keyword-index)\n')
    for title, bl in main:
        o.append('## ' + title + '\n')
        o.append(blocks(bl))
    o.append('## Language reference\n')
    o.append('Every statement and function, grouped by category. Syntax notation: `[ ]` = optional, `{ }` = repeatable, `|` = alternative. '
             'Statement and function names can be written in upper or lower case.\n')
    for c in cats:
        o.append('## ' + c + '\n')
        for t in TOPICS:
            if t['cat'] == c:
                o.append(topic(t))
    for title, bl in last:
        o.append('## ' + title + '\n')
        o.append(blocks(bl))
    names = sorted({n for t in TOPICS if t['cat'] != 'Guide' for n in t['names']}, key=lambda s: s.upper())
    o.append('## Keyword index\n')
    o.append(' '.join('`%s`' % n for n in names) + '\n')
    text = '\n'.join(o)
    text = re.sub(r'\n{3,}', '\n\n', text)
    with open(fn, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    return fn


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'MANUAL.md')
    build(out)
    print('written', out, os.path.getsize(out), 'byte')
