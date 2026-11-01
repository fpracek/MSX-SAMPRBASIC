# -*- coding: utf-8 -*-
"""Generates the data of the VS Code extension from the single documentation source and from the compiler tables:
vscode/data/help.json, vscode/data/keywords.json, vscode/syntaxes/samprbasic.tmLanguage.json, vscode/snippets/samprbasic.json."""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
sys.path.insert(0, HERE)
import topics_core
import topics_hw
import topics_guide  # noqa: F401
from topics_core import TOPICS

OUT = os.path.join(ROOT, 'vscode')


def table(src, label):
    m = re.search(label + r':\s*(db .*?)(?=\n\w|\n\s*dw|\n\s*;)', src, re.S)
    words = []
    for ln in m.group(1).split('\n'):
        ln = ln.strip()
        if not ln.startswith('db'):
            continue
        words += re.findall(r'"([A-Z$_0-9]+)"', ln)
    return words


def main():
    asm = open(os.path.join(ROOT, 'onmsx', 'qbc.asm'), encoding='utf-8').read()
    kw = table(asm, 'kwtab')
    fn = table(asm, 'bitab')
    kw = [k for k in kw if k]
    fn = [f for f in fn if f]
    extra_kw = ['END IF', 'END SUB', 'END FUNCTION', 'END SELECT', 'EXIT', 'ELSEIF', 'ELSE', 'DEFINT', 'AS', 'MAPPER', 'FOR', 'INPUT', 'OUTPUT', 'APPEND', 'RANDOM',
                'PSET', 'PRESET', 'AND', 'OR', 'XOR', 'TPSET', 'TPRESET', 'MOV', 'B', 'BF', 'FAR', 'PAGE', 'SCROLL', 'SPRITE', 'LABELS', 'NUMBERED', 'MIXED', 'TARGET', 'DEBUG']
    statements = sorted(set(k for k in kw if k not in ('AND', 'OR', 'XOR', 'NOT', 'MOD', 'TO', 'STEP', 'THEN', 'IS', 'AS')))
    operators = ['AND', 'OR', 'XOR', 'NOT', 'MOD', 'TO', 'STEP', 'THEN', 'IS']
    targets = ['DOS', 'COM', 'BIN', 'ROM_16', 'ROM_32', 'ROM_ASCII8', 'ROM_ASCII16', 'ROM_KONAMI', 'ROM_KONAMISCC', 'ROM_SCC', 'ROM16', 'ROM32', 'ASCII8', 'ASCII16', 'KONAMI', 'SCC']
    json.dump({'statements': statements, 'functions': sorted(set(fn)), 'operators': operators, 'targets': targets, 'extra': extra_kw},
              open(os.path.join(OUT, 'data', 'keywords.json'), 'w', encoding='utf-8'), indent=1)

    help_ = [dict(names=t['names'], category=t['cat'], syntax=t['syn'], description=t['desc'].replace('`', ''), example=t['ex'], see=t['see'], availability=t['avail'])
             for t in TOPICS]
    json.dump(help_, open(os.path.join(OUT, 'data', 'help.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)

    def alt(words):
        ws = sorted(set(words), key=lambda w: (-len(w), w))
        return '|'.join(re.escape(w).replace(r'\ ', r'\s+') for w in ws)

    stmts = alt(statements + ['END IF', 'END SUB', 'END FUNCTION', 'END SELECT', 'EXIT FOR', 'EXIT DO', 'EXIT WHILE', 'EXIT SUB', 'EXIT FUNCTION', 'CASE ELSE', 'SELECT CASE',
                              'LINE INPUT', 'PUT SPRITE', 'CALL FAR', 'SET PAGE', 'SET SCROLL', 'COLOR SPRITE'])
    funcs = alt([f.rstrip('$') for f in fn])
    grammar = {
        'name': 'SamPr Basic', 'scopeName': 'source.samprbasic',
        'patterns': [{'include': '#asm'}, {'include': '#comment'}, {'include': '#string'}, {'include': '#label'}, {'include': '#linenumber'},
                     {'include': '#subdef'}, {'include': '#number'}, {'include': '#option'}, {'include': '#operator'}, {'include': '#statement'}, {'include': '#function'}],
        'repository': {
            'comment': {'patterns': [{'name': 'comment.line.samprbasic', 'match': r"(?i)(?:\bREM\b|').*$"}]},
            'string': {'name': 'string.quoted.double.samprbasic', 'begin': '"', 'end': '"|$'},
            'label': {'name': 'entity.name.label.samprbasic', 'match': r'^\s*([A-Za-z_][A-Za-z0-9_]*):(?!=)', 'captures': {'1': {'name': 'entity.name.label.samprbasic'}}},
            'linenumber': {'name': 'constant.numeric.linenumber.samprbasic', 'match': r'^\s*\d+\b'},
            'subdef': {'match': r'(?i)\b(SUB|FUNCTION)\s+([A-Za-z_][A-Za-z0-9_]*\$?)', 'captures': {'1': {'name': 'keyword.control.samprbasic'}, '2': {'name': 'entity.name.function.samprbasic'}}},
            'number': {'name': 'constant.numeric.samprbasic', 'match': r'(?i)&H[0-9A-F]+|&B[01]+|\b\d+\b'},
            'option': {'match': r'(?i)\b(OPTION)\s+(TARGET)\s+(' + alt(targets) + r')\b', 'captures': {'1': {'name': 'keyword.control.samprbasic'}, '2': {'name': 'keyword.control.samprbasic'}, '3': {'name': 'support.constant.samprbasic'}}},
            'operator': {'name': 'keyword.operator.word.samprbasic', 'match': r'(?i)\b(' + alt(operators) + r')\b'},
            'statement': {'name': 'keyword.control.samprbasic', 'match': r'(?i)\b(' + stmts + r')\b'},
            'function': {'name': 'support.function.samprbasic', 'match': r'(?i)\b(' + funcs + r')\$?(?=\s*\(|\b)'},
            'asm': {'name': 'meta.embedded.block.asm.samprbasic', 'begin': r'(?i)^\s*(__ASM)\b', 'end': r'(?i)^\s*(__ENDASM)\b',
                    'beginCaptures': {'1': {'name': 'keyword.control.samprbasic'}}, 'endCaptures': {'1': {'name': 'keyword.control.samprbasic'}},
                    'patterns': [{'name': 'comment.line.semicolon.asm', 'match': ';.*$'},
                                 {'name': 'string.quoted.double.asm', 'match': r'"[^"]*"'},
                                 {'name': 'support.type.register.asm', 'match': r"(?i)\b(AF'?|BC|DE|HL|IX|IY|SP|IXH|IXL|IYH|IYL|[ABCDEHLIR])\b"},
                                 {'name': 'keyword.operator.condition.asm', 'match': r'(?i)\b(NZ|NC|PO|PE|[ZCPM])(?=\s*,)'},
                                 {'name': 'keyword.other.mnemonic.asm', 'match': r'(?i)\b(ADC|ADD|AND|BIT|CALL|CCF|CP|CPD|CPDR|CPI|CPIR|CPL|DAA|DEC|DI|DJNZ|EI|EX|EXX|HALT|IM|IN|INC|IND|INDR|INI|INIR|JP|JR|LD|LDD|LDDR|LDI|LDIR|NEG|NOP|OR|OTDR|OTIR|OUT|OUTD|OUTI|POP|PUSH|RES|RET|RETI|RETN|RL|RLA|RLC|RLCA|RLD|RR|RRA|RRC|RRCA|RRD|RST|SBC|SCF|SET|SLA|SRA|SRL|SUB|XOR)\b'},
                                 {'name': 'keyword.control.directive.asm', 'match': r'(?i)\b(DB|DEFB|DW|DEFW|DS|DEFS|EQU)\b'},
                                 {'name': 'constant.numeric.asm', 'match': r'(?i)\$[0-9A-F]+|0x[0-9A-F]+|\b[0-9][0-9A-F]*H\b|%[01]+|\b[01]+B\b|\b\d+\b'},
                                 {'name': 'entity.name.label.asm', 'match': r'^\s*[A-Za-z_][A-Za-z0-9_]*:'}]},
        }}
    json.dump(grammar, open(os.path.join(OUT, 'syntaxes', 'samprbasic.tmLanguage.json'), 'w', encoding='utf-8'), indent=1)

    os.makedirs(os.path.join(OUT, 'snippets'), exist_ok=True)
    snippets = {
        'SUB': {'prefix': 'sub', 'body': ['SUB ${1:name}(${2})', '  $0', 'END SUB'], 'description': 'SUB procedure'},
        'FUNCTION': {'prefix': 'function', 'body': ['FUNCTION ${1:name}(${2})', '  ${1:name} = ${3:0}', 'END FUNCTION'], 'description': 'FUNCTION'},
        'IF': {'prefix': 'if', 'body': ['IF ${1:condition} THEN', '  $0', 'END IF'], 'description': 'IF block'},
        'IFELSE': {'prefix': 'ifelse', 'body': ['IF ${1:condition} THEN', '  $2', 'ELSE', '  $0', 'END IF'], 'description': 'IF/ELSE block'},
        'FOR': {'prefix': 'for', 'body': ['FOR ${1:i} = ${2:1} TO ${3:10}', '  $0', 'NEXT ${1:i}'], 'description': 'FOR loop'},
        'WHILE': {'prefix': 'while', 'body': ['WHILE ${1:condition}', '  $0', 'WEND'], 'description': 'WHILE loop'},
        'DO': {'prefix': 'do', 'body': ['DO', '  $0', 'LOOP UNTIL ${1:condition}'], 'description': 'DO loop'},
        'SELECT': {'prefix': 'select', 'body': ['SELECT CASE ${1:value}', '  CASE ${2:1}', '    $0', '  CASE ELSE', '    ', 'END SELECT'], 'description': 'SELECT CASE'},
        'ASM': {'prefix': 'asm', 'body': ['__ASM', '  $0', '__ENDASM'], 'description': 'Inline Z80 assembler block'},
        'TARGET': {'prefix': 'target', 'body': ['OPTION TARGET ${1|DOS,BIN,ROM_16,ROM_32,ROM_ASCII8,ROM_ASCII16,ROM_KONAMI,ROM_KONAMISCC|}'], 'description': 'Output type'},
    }
    json.dump(snippets, open(os.path.join(OUT, 'snippets', 'samprbasic.json'), 'w', encoding='utf-8'), indent=1)
    print('statements', len(statements), 'functions', len(set(fn)), 'help topics', len(help_))


if __name__ == '__main__':
    main()
