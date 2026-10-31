import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import qbc

cases = [
    ('LABELS con numero di riga',  'OPTION LABELS\n10 PRINT 1\n',            "non sono ammessi"),
    ('LABELS con GOTO numerico',   'OPTION LABELS\nGOTO 10\n',               "usa un'etichetta"),
    ('NUMBERED senza numero',      'OPTION NUMBERED\n10 PRINT 1\nPRINT 2\n', "manca il numero"),
    ('NUMBERED duplicato',         'OPTION NUMBERED\n10 PRINT 1\n10 PRINT 2\n', "duplicato"),
    ('NUMBERED con etichetta',     'OPTION NUMBERED\n10 foo:\n',             "etichette non sono ammesse"),
    ('NUMBERED con GOTO a nome',   'OPTION NUMBERED\n10 GOTO foo\n',         "usa un numero"),
    ('GOTO a riga inesistente',    '10 GOTO 99\n',                           "inesistente: 99"),
    ('GOTO a etichetta inesistente', 'GOTO nope\n',                          "inesistente: NOPE"),
    ('OPTION errata',              'OPTION FOO\n',                           "OPTION"),
]
bad = 0
for name, src, want in cases:
    try:
        qbc.compile_source(src)
        print('FALLITO (nessun errore):', name); bad += 1
    except qbc.CompileError as e:
        ok = want in str(e)
        print(('ok       ' if ok else 'FALLITO  ') + name + ' -> ' + str(e))
        bad += not ok
# MIXED: numeri e etichette insieme devono compilare
qbc.compile_source('10 PRINT 1\nfoo:\nGOTO foo\nGOTO 10\n')
print('ok       MIXED accetta entrambi')
sys.exit(1 if bad else 0)
