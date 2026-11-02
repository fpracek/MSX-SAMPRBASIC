# -*- coding: utf-8 -*-
"""Builds the SamPr Basic PDF manual. usage: python gen_pdf.py [output.pdf]"""
import os
import re
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, Frame, Image, KeepTogether, NextPageTemplate, PageBreak, PageTemplate, Paragraph,
                                Preformatted, Spacer, Table, TableStyle)
from reportlab.platypus.tableofcontents import TableOfContents

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import topics_core
import topics_hw
import topics_guide  # noqa: F401
from chapters import CHAPTERS
from topics_core import TOPICS

IMG = os.path.join(HERE, 'img')
NAVY = colors.HexColor('#0b1b4d')
BLUE = colors.HexColor('#1f4fd8')
CYAN = colors.HexColor('#35c2ff')
YEL = colors.HexColor('#ffd34d')
LIGHT = colors.HexColor('#eef3ff')
CODEBG = colors.HexColor('#f3f5fa')
GREY = colors.HexColor('#5a6275')
VERSION = 'SamPr Basic 1.0'

ss = getSampleStyleSheet()
BODY = ParagraphStyle('body', parent=ss['BodyText'], fontName='Helvetica', fontSize=10, leading=14.2, alignment=TA_JUSTIFY, spaceAfter=6)
H1 = ParagraphStyle('h1', parent=ss['Heading1'], fontName='Helvetica-Bold', fontSize=22, leading=26, textColor=NAVY, spaceBefore=0, spaceAfter=14)
H2 = ParagraphStyle('h2', parent=ss['Heading2'], fontName='Helvetica-Bold', fontSize=13.5, leading=17, textColor=BLUE, spaceBefore=12, spaceAfter=5)
H3 = ParagraphStyle('h3', parent=ss['Heading3'], fontName='Helvetica-Bold', fontSize=11, leading=14, textColor=NAVY, spaceBefore=6, spaceAfter=3)
CODE = ParagraphStyle('code', fontName='Courier', fontSize=8.8, leading=11.2, textColor=colors.HexColor('#111a33'))
SYN = ParagraphStyle('syn', fontName='Courier-Bold', fontSize=9.4, leading=12, textColor=NAVY)
SMALL = ParagraphStyle('small', parent=BODY, fontSize=8.6, leading=11.5, textColor=GREY, alignment=0)
CELL = ParagraphStyle('cell', parent=BODY, fontSize=9.2, leading=12, alignment=0, spaceAfter=0)
CELLB = ParagraphStyle('cellb', parent=CELL, fontName='Helvetica-Bold', textColor=colors.white)
BUL = ParagraphStyle('bul', parent=BODY, leftIndent=14, bulletIndent=3, spaceAfter=3, alignment=0)
TOC1 = ParagraphStyle('toc1', fontName='Helvetica-Bold', fontSize=11, leading=17, leftIndent=0, textColor=NAVY)
TOC2 = ParagraphStyle('toc2', fontName='Helvetica', fontSize=9.5, leading=13, leftIndent=14, textColor=GREY)


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def md(s):
    """topic text: `code` -> Courier, the rest escaped"""
    parts = re.split(r'(`[^`]*`)', s)
    out = ''
    for p in parts:
        if p.startswith('`') and p.endswith('`') and len(p) > 1:
            out += "<font face='Courier' color='#1f4fd8'>%s</font>" % esc(p[1:-1])
        else:
            out += esc(p)
    return out


class Doc(BaseDocTemplate):
    def __init__(self, fn):
        super().__init__(fn, pagesize=A4, leftMargin=22 * mm, rightMargin=20 * mm, topMargin=24 * mm, bottomMargin=20 * mm,
                         title='SamPr Basic - User manual', author='Fausto Pracek', subject='BASIC compiler and IDE for MSX')
        fr = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id='f')
        self.addPageTemplates([PageTemplate(id='cover', frames=[Frame(0, 0, A4[0], A4[1], id='c', leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)], onPage=cover_page),
                               PageTemplate(id='main', frames=[fr], onPageEnd=page_deco)])
        self.chapter = ''

    def beforeDocument(self):
        self._bk = 0
        self.chapter = ''

    def afterFlowable(self, f):
        if isinstance(f, Paragraph):
            st = f.style.name
            if st == 'h1':
                self.chapter = f.getPlainText()
                key = 'h1-%d' % self._bk
                self._bk += 1
                self.canv.bookmarkPage(key)
                self.canv.addOutlineEntry(self.chapter, key, 0, 0)
                self.notify('TOCEntry', (0, self.chapter, self.page, key))
            elif st == 'h2c':
                key = 'h2-%d' % self._bk
                self._bk += 1
                self.canv.bookmarkPage(key)
                self.canv.addOutlineEntry(f.getPlainText(), key, 1, 1)
                self.notify('TOCEntry', (1, f.getPlainText(), self.page, key))

    _bk = 0


def cover_page(c, doc):
    W, H = A4
    # background
    c.setFillColor(NAVY)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    # MSX-style "pixel" bands
    px = 14
    pal = [BLUE, CYAN, YEL, colors.HexColor('#ff5a5a'), colors.HexColor('#7be07b'), colors.HexColor('#b57bff')]
    import random
    random.seed(7)
    for gx in range(int(W // px) + 1):
        for gy in range(0, 9):
            if random.random() < 0.55 * (1 - gy / 9.0):
                c.setFillColor(pal[random.randrange(len(pal))])
                c.setFillAlpha(0.20 + 0.5 * (1 - gy / 9.0))
                c.rect(gx * px, H - (gy + 1) * px, px - 2, px - 2, stroke=0, fill=1)
    c.setFillAlpha(1)
    # color bar
    bw = W / len(pal)
    for i, col in enumerate(pal):
        c.setFillColor(col)
        c.rect(i * bw, H * 0.40, bw, 6, stroke=0, fill=1)
    # title
    c.setFillColor(colors.white)
    c.setFont('Helvetica-Bold', 54)
    c.drawString(30 * mm, H * 0.60, 'SamPr')
    c.setFillColor(YEL)
    c.drawString(30 * mm, H * 0.60 - 62, 'Basic')
    c.setFillColor(CYAN)
    c.setFont('Helvetica-Bold', 17)
    c.drawString(30 * mm, H * 0.60 - 98, 'BASIC compiler and development environment for MSX')
    c.setFillColor(colors.HexColor('#c8d4ff'))
    c.setFont('Helvetica', 12)
    c.drawString(30 * mm, H * 0.60 - 120, 'Editor, Z80 compiler, inline assembler and debugger — all on the MSX')
    # fake MSX screen
    sx, sy, sw, sh = 30 * mm, H * 0.40 + 40, 150 * mm, 0
    c.setFillColor(colors.HexColor('#e9edf9'))
    c.setFont('Helvetica-Bold', 13)
    c.drawString(30 * mm, H * 0.40 - 30, 'User manual and language reference')
    c.setFont('Helvetica', 11)
    c.setFillColor(colors.HexColor('#9fb2e8'))
    c.drawString(30 * mm, H * 0.40 - 50, 'Version 1.0  ·  MSX1 / MSX2 / MSX2+ / turbo R  ·  MSX-DOS 1 and 2')
    c.setFillColor(colors.white)
    c.setFont('Helvetica-Bold', 12)
    c.drawString(30 * mm, 36 * mm, '2026  Fausto Pracek')
    c.setFont('Courier', 10)
    c.setFillColor(YEL)
    c.drawString(30 * mm, 28 * mm, 'PRINT "Hello MSX!"')
    c.setFillColor(colors.white)
    # blinking cursor
    c.rect(30 * mm + 112, 28 * mm - 1, 6, 11, stroke=0, fill=1)


def page_deco(c, doc):
    W, H = A4
    c.saveState()
    c.setFillColor(NAVY)
    c.rect(0, H - 14 * mm, W, 14 * mm, stroke=0, fill=1)
    for i, col in enumerate([BLUE, CYAN, YEL, colors.HexColor('#ff5a5a')]):
        c.setFillColor(col)
        c.rect(W - 22 * mm + i * 4 * mm, H - 14 * mm, 4 * mm, 14 * mm, stroke=0, fill=1)
    c.setFillColor(colors.white)
    c.setFont('Helvetica-Bold', 9.5)
    c.drawString(22 * mm, H - 9 * mm, VERSION)
    c.setFont('Helvetica', 9)
    c.drawString(60 * mm, H - 9 * mm, doc.chapter[:70])
    c.setFillColor(GREY)
    c.setFont('Helvetica', 8.5)
    c.drawString(22 * mm, 10 * mm, '2026 Fausto Pracek')
    c.drawRightString(W - 20 * mm, 10 * mm, 'Page %d' % (doc.page - 1))
    c.restoreState()


def code_block(text):
    t = Table([[Preformatted(text, CODE)]], colWidths=[None])
    t.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), CODEBG), ('LINEBEFORE', (0, 0), (0, -1), 2.5, CYAN),
                           ('LEFTPADDING', (0, 0), (-1, -1), 9), ('TOPPADDING', (0, 0), (-1, -1), 5), ('BOTTOMPADDING', (0, 0), (-1, -1), 5)]))
    return t


def table_block(rows, widths):
    data = []
    for i, r in enumerate(rows):
        data.append([Paragraph(c, CELLB if i == 0 else CELL) for c in r])
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, 0), BLUE), ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, LIGHT]),
                           ('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#c8d2ee')), ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                           ('TOPPADDING', (0, 0), (-1, -1), 3), ('BOTTOMPADDING', (0, 0), (-1, -1), 3)]))
    return t


def blocks_to_flow(blocks):
    out = []
    for b in blocks:
        k = b[0]
        if k == 'p':
            out.append(Paragraph(b[1], BODY))
        elif k == 'h':
            out.append(Paragraph(b[1], H2))
        elif k == 'code':
            out += [code_block(b[1]), Spacer(1, 8)]
        elif k == 'ul':
            for it in b[1]:
                out.append(Paragraph(it, BUL, bulletText='•'))
            out.append(Spacer(1, 4))
        elif k == 'table':
            out += [table_block(b[1], b[2]), Spacer(1, 8)]
        elif k == 'img':
            p = os.path.join(IMG, b[1])
            if os.path.exists(p):
                from PIL import Image as PI
                w, h = PI.open(p).size
                tw = min(150 * mm, w)
                out.append(KeepTogether([Image(p, width=tw, height=tw * h / w), Paragraph(b[2], SMALL), Spacer(1, 8)]))
    return out


def topic_flow(t):
    name = t['names'][0]
    items = [Paragraph(esc(name), H3)]
    syn = '\n'.join(t['syn'])
    items.append(code_block(syn) if False else Preformatted(syn, SYN))
    items.append(Spacer(1, 3))
    items.append(Paragraph(md(t['desc']), BODY))
    if t['avail'] != 'MSX1 and MSX2':
        items.append(Paragraph('<b>Availability:</b> ' + esc(t['avail']), SMALL))
    if t['ex']:
        items.append(code_block(t['ex']))
    if t['see']:
        items.append(Paragraph('See also: ' + ', '.join(esc(x) for x in t['see']), SMALL))
    items.append(Spacer(1, 6))
    return [KeepTogether(items[:5] if len(items) > 5 else items)] + items[5:]


def build(fn):
    doc = Doc(fn)
    story = [NextPageTemplate('main'), PageBreak()]
    toc = TableOfContents()
    toc.levelStyles = [TOC1, TOC2]
    story += [Paragraph('Contents', H1), toc, PageBreak()]
    for title, blocks in CHAPTERS:
        if title == 'Errors and limits':
            continue
        story.append(Paragraph(esc(title), H1))
        story += blocks_to_flow(blocks)
        story.append(PageBreak())
    # reference
    story.append(Paragraph('Language reference', H1))
    story.append(Paragraph("Every statement and function, grouped by category. Syntax notation: <font face='Courier'>[ ]</font> = optional, "
                           "<font face='Courier'>{ }</font> = repeatable, <font face='Courier'>|</font> = alternative. Statement and function names "
                           "can be written in upper or lower case.", BODY))
    cats = []
    for t in TOPICS:
        if t['cat'] not in cats:
            cats.append(t['cat'])
    for c in cats:
        if c == 'Guide':
            continue
        story.append(Paragraph(esc(c), ParagraphStyle('h2c', parent=H2, fontSize=15, textColor=NAVY, spaceBefore=16)))
        for t in TOPICS:
            if t['cat'] == c:
                story += topic_flow(t)
    story.append(PageBreak())
    for title, blocks in CHAPTERS:
        if title != 'Errors and limits':
            continue
        story.append(Paragraph(esc(title), H1))
        story += blocks_to_flow(blocks)
    # alphabetical index
    story.append(PageBreak())
    story.append(Paragraph('Keyword index', H1))
    names = sorted({n for t in TOPICS for n in t['names']}, key=lambda s: s.upper())
    cols = 4
    rows = []
    per = (len(names) + cols - 1) // cols
    for i in range(per):
        rows.append([Paragraph("<font face='Courier'>%s</font>" % esc(names[i + j * per]) if i + j * per < len(names) else '', CELL) for j in range(cols)])
    t = Table(rows, colWidths=[doc.width / cols] * cols)
    t.setStyle(TableStyle([('TOPPADDING', (0, 0), (-1, -1), 1), ('BOTTOMPADDING', (0, 0), (-1, -1), 1)]))
    story.append(t)
    doc.multiBuild(story)
    return fn


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'SamPrBasic-Manual.pdf')
    build(out)
    print('written', out, os.path.getsize(out), 'byte')
