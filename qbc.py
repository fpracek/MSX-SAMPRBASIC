#!/usr/bin/env python3
"""MSXQB prototype compiler: dialetto stile QuickBASIC -> Z80 (sjasmplus).

Parse one-pass con emissione diretta (niente AST), cosi' da poter essere
riscritto 1:1 in Z80. Tipi: INTEGER 16 bit (default, suffisso %) e STRING ($).
"""
import re
import sys


class CompileError(Exception):
    pass


MODES = ('numbered', 'labels', 'mixed')


TOKEN_RE = re.compile(r'''
    (?P<ws>[ \t]+)
  | (?P<str>"[^"]*")
  | (?P<hex>&H[0-9A-Fa-f]+)
  | (?P<bin>&B[01]+)
  | (?P<num>\d+)
  | (?P<id>[A-Za-z_][A-Za-z0-9_]*[$%]?)
  | (?P<op><>|<=|>=|=<|=>|[-+*/\\()=<>,;:?])
''', re.X)

BOOL_CALL = {'=': 'b_eq', '<>': 'b_ne', '<': 'b_lt', '>': 'b_gt',
             '<=': 'b_le', '>=': 'b_ge', '=<': 'b_le', '=>': 'b_ge'}


def lex(line, lineno):
    toks = []
    pos = 0
    while pos < len(line):
        if line[pos] == "'":
            break
        m = TOKEN_RE.match(line, pos)
        if not m:
            raise CompileError(f"{lineno}: carattere inatteso {line[pos]!r}")
        pos = m.end()
        k = m.lastgroup
        t = m.group(k)
        if k == 'ws':
            continue
        if k == 'str':
            toks.append(('S', t[1:-1]))
        elif k == 'hex':
            toks.append(('N', int(t[2:], 16)))
        elif k == 'bin':
            toks.append(('N', int(t[2:], 2)))
        elif k == 'num':
            toks.append(('N', int(t)))
        elif k == 'id':
            if t.upper() == 'REM':
                break
            toks.append(('I', t.upper()))
        else:
            toks.append(('P', t))
    return toks


def vtype(name):
    return 'S' if name.endswith('$') else 'I'


def sym(name):
    return name.replace('$', '_s').replace('%', '_i')


class Func:
    def __init__(self, kind, name, params):
        self.kind = kind
        self.name = name
        self.params = params          # [(name, type)]
        self.ret = vtype(name) if kind == 'FUNCTION' else None
        self.label = 'f_' + sym(name)
        self.locals = {}              # name -> ('I', disp) | ('S', frameoff)
        self.nint = 0
        self.nstr = 0
        self.shared = set()
        self.exit = None


class Compiler:
    def __init__(self, source, mode='mixed'):
        self.lines = source.splitlines()
        self.code = []
        self.lits = {}
        self.gvars = {}               # name -> offset
        self.gsize = 0
        self.arrays = {}              # name -> (label, count)
        self.consts = {}
        self.funcs = {}
        self.cur = None               # Func in compilazione
        self.blocks = []
        self.nlab = 0
        self.tmp = False
        self.toks = []
        self.pos = 0
        self.lineno = 0
        self.mode = mode
        self.refs = []                # (label, lineno) di GOTO/GOSUB/THEN
        self.defined = set()

    # ------------------------------------------------------------ utilita'
    def err(self, msg):
        raise CompileError(f"riga {self.lineno}: {msg}")

    def emit(self, s):
        self.code.append(s if s.endswith(':') else '        ' + s)

    def label(self, name):
        self.code.append(name + ':')

    def newlab(self, p='L'):
        self.nlab += 1
        return f'{p}{self.nlab}'

    def peek(self, off=0):
        i = self.pos + off
        return self.toks[i] if i < len(self.toks) else ('E', None)

    def next(self):
        t = self.peek()
        self.pos += 1
        return t

    def is_kw(self, w, off=0):
        t = self.peek(off)
        return t == ('I', w)

    def is_p(self, p, off=0):
        return self.peek(off) == ('P', p)

    def accept_kw(self, w):
        if self.is_kw(w):
            self.pos += 1
            return True
        return False

    def accept_p(self, p):
        if self.is_p(p):
            self.pos += 1
            return True
        return False

    def expect_p(self, p):
        if not self.accept_p(p):
            self.err(f"atteso '{p}'")

    def expect_kw(self, w):
        if not self.accept_kw(w):
            self.err(f"atteso {w}")

    def at_end(self):
        return self.peek()[0] == 'E'

    def at_stmt_end(self):
        return self.at_end() or self.is_p(':') or self.is_kw('ELSE')

    def ident(self):
        t = self.next()
        if t[0] != 'I':
            self.err("atteso identificatore")
        return t[1]

    # ------------------------------------------------------------ variabili
    def gaddr(self, name):
        if name not in self.gvars:
            self.gvars[name] = self.gsize
            self.gsize += 256 if vtype(name) == 'S' else 2
        return 'v_' + sym(name)

    def resolve(self, name):
        """-> ('G',label) | ('L',disp) | ('LS',off) | ('P',disp) | ('PS',disp)"""
        f = self.cur
        if f and name not in f.shared:
            for i, (pn, pt) in enumerate(f.params):
                if pn == name:
                    d = 4 + 2 * (len(f.params) - 1 - i)
                    return ('P' if pt == 'I' else 'PS', d)
            if name not in f.locals:
                if vtype(name) == 'I':
                    f.nint += 1
                    if f.nint > 30:
                        self.err("troppe variabili locali intere")
                    f.locals[name] = ('I', -2 * f.nint)
                else:
                    f.nstr += 1
                    f.locals[name] = ('S', -(64 + 256 * f.nstr))
            kind, d = f.locals[name]
            return ('L' if kind == 'I' else 'LS', d)
        return ('G', self.gaddr(name))

    def ptr_local(self, d):
        """HL = IX + d (clobbera DE)"""
        self.emit('push ix')
        self.emit('pop hl')
        self.emit(f'ld de,{d}')
        self.emit('add hl,de')

    def load_var(self, name):
        kind, v = self.resolve(name)
        t = vtype(name)
        if kind == 'G':
            self.emit(f'ld hl,({v})' if t == 'I' else f'ld hl,{v}')
        elif kind == 'L':
            self.emit(f'ld l,(ix{v:+d})')
            self.emit(f'ld h,(ix{v + 1:+d})')
        elif kind == 'LS':
            self.ptr_local(v)
        elif kind == 'P':
            self.emit(f'ld l,(ix+{v})')
            self.emit(f'ld h,(ix+{v + 1})')
        else:  # PS
            self.emit(f'ld l,(ix+{v})')
            self.emit(f'ld h,(ix+{v + 1})')
        return t

    def store_var(self, name):
        """valore in HL -> variabile"""
        kind, v = self.resolve(name)
        if vtype(name) == 'I':
            if kind == 'G':
                self.emit(f'ld ({v}),hl')
            elif kind == 'L':
                self.emit(f'ld (ix{v:+d}),l')
                self.emit(f'ld (ix{v + 1:+d}),h')
            elif kind == 'P':
                self.emit(f'ld (ix+{v}),l')
                self.emit(f'ld (ix+{v + 1}),h')
        else:
            if kind == 'G':
                self.emit(f'ld de,{v}')
            elif kind == 'LS':
                self.emit('push hl')
                self.ptr_local(v)
                self.emit('ex de,hl')
                self.emit('pop hl')
            else:
                self.err("assegnamento a parametro stringa non supportato")
            self.emit('call rt_scopy')

    def strlit(self, text):
        if text not in self.lits:
            self.lits[text] = f'str_{len(self.lits)}'
        return self.lits[text]

    # ------------------------------------------------------------ espressioni
    def expr(self):
        return self.e_or()

    def want(self, t, got):
        if t != got:
            self.err("tipo non compatibile (intero/stringa)")

    def e_or(self):
        t = self.e_and()
        while self.is_kw('OR') or self.is_kw('XOR'):
            op = self.next()[1]
            self.want('I', t)
            self.emit('push hl')
            self.want('I', self.e_and())
            self.emit('pop de')
            self.emit('ld a,h')
            self.emit(f'{op.lower()} d')
            self.emit('ld h,a')
            self.emit('ld a,l')
            self.emit(f'{op.lower()} e')
            self.emit('ld l,a')
        return t

    def e_and(self):
        t = self.e_not()
        while self.is_kw('AND'):
            self.next()
            self.want('I', t)
            self.emit('push hl')
            self.want('I', self.e_not())
            self.emit('pop de')
            self.emit('ld a,h')
            self.emit('and d')
            self.emit('ld h,a')
            self.emit('ld a,l')
            self.emit('and e')
            self.emit('ld l,a')
        return t

    def e_not(self):
        if self.accept_kw('NOT'):
            self.want('I', self.e_not())
            self.emit('ld a,h')
            self.emit('cpl')
            self.emit('ld h,a')
            self.emit('ld a,l')
            self.emit('cpl')
            self.emit('ld l,a')
            return 'I'
        return self.e_cmp()

    def e_cmp(self):
        t = self.e_add()
        while self.peek()[0] == 'P' and self.peek()[1] in BOOL_CALL:
            op = self.next()[1]
            self.emit('push hl')
            t2 = self.e_add()
            self.want(t, t2)
            self.emit('pop de')
            self.emit('call rt_cmp' if t == 'I' else 'call rt_scmp')
            self.emit(f'call {BOOL_CALL[op]}')
            t = 'I'
        return t

    def e_add(self):
        t = self.e_mod()
        while self.is_p('+') or self.is_p('-'):
            op = self.next()[1]
            self.emit('push hl')
            t2 = self.e_mod()
            self.want(t, t2)
            self.emit('pop de')
            if t == 'S':
                if op == '-':
                    self.err("operatore '-' su stringhe")
                self.emit('call rt_scat')
                self.tmp = True
            elif op == '+':
                self.emit('add hl,de')
            else:
                self.emit('ex de,hl')
                self.emit('or a')
                self.emit('sbc hl,de')
        return t

    def e_mod(self):
        t = self.e_idiv()
        while self.is_kw('MOD'):
            self.next()
            self.want('I', t)
            self.emit('push hl')
            self.want('I', self.e_idiv())
            self.emit('pop de')
            self.emit('ex de,hl')
            self.emit('call rt_mod')
        return t

    def e_idiv(self):
        t = self.e_mul()
        while self.is_p('\\'):
            self.next()
            self.want('I', t)
            self.emit('push hl')
            self.want('I', self.e_mul())
            self.emit('pop de')
            self.emit('ex de,hl')
            self.emit('call rt_div')
        return t

    def e_mul(self):
        t = self.e_unary()
        while self.is_p('*') or self.is_p('/'):
            op = self.next()[1]
            self.want('I', t)
            self.emit('push hl')
            self.want('I', self.e_unary())
            self.emit('pop de')
            if op == '*':
                self.emit('call rt_mul')
            else:                      # '/' = divisione intera (v0, niente float)
                self.emit('ex de,hl')
                self.emit('call rt_div')
        return t

    def e_unary(self):
        if self.accept_p('-'):
            self.want('I', self.e_unary())
            self.emit('ex de,hl')
            self.emit('ld hl,0')
            self.emit('or a')
            self.emit('sbc hl,de')
            return 'I'
        if self.accept_p('+'):
            return self.e_unary()
        return self.primary()

    def args(self, n_min, n_max):
        """parse '(' a, b, ... ')' ; ritorna lista dei tipi; lascia gli argomenti
        precedenti sullo stack e l'ultimo in HL"""
        self.expect_p('(')
        types = []
        while True:
            types.append(self.expr())
            if self.accept_p(','):
                self.emit('push hl')
                continue
            break
        self.expect_p(')')
        if not n_min <= len(types) <= n_max:
            self.err("numero di argomenti errato")
        return types

    def builtin(self, name):
        """chiamata funzione predefinita; None se non e' un builtin"""
        e = self.emit
        if name in ('LEN', 'ASC', 'VAL'):
            self.want('S', self.args(1, 1)[0])
            e({'LEN': 'call rt_len', 'ASC': 'call rt_asc', 'VAL': 'call rt_val'}[name])
            return 'I'
        if name in ('ABS', 'SGN', 'RND', 'PEEK', 'VPEEK', 'INP', 'CHR$', 'STR$'):
            self.want('I', self.args(1, 1)[0])
            if name == 'ABS':
                lab = self.newlab()
                e('bit 7,h')
                e(f'jr z,{lab}')
                e('call rt_neghl')
                self.label(lab)
                return 'I'
            if name == 'SGN':
                l1, l2 = self.newlab(), self.newlab()
                e('bit 7,h')
                e(f'jr nz,{l1}')
                e('ld a,h')
                e('or l')
                e(f'jr z,{l2}')
                e('ld hl,1')
                e(f'jr {l2}')
                self.label(l1)
                e('ld hl,-1')
                self.label(l2)
                return 'I'
            if name == 'RND':
                e('call rt_rnd')
            elif name == 'PEEK':
                e('ld a,(hl)')
                e('ld l,a')
                e('ld h,0')
            elif name == 'VPEEK':
                e('call RDVRM')
                e('ld l,a')
                e('ld h,0')
            elif name == 'INP':
                e('ld c,l')
                e('in a,(c)')
                e('ld l,a')
                e('ld h,0')
            elif name == 'CHR$':
                e('call rt_chr')
                self.tmp = True
                return 'S'
            else:
                e('call rt_str')
                self.tmp = True
                return 'S'
            return 'I'
        if name in ('LEFT$', 'RIGHT$'):
            ts = self.args(2, 2)
            self.want('S', ts[0])
            self.want('I', ts[1])
            e('pop de')
            e('call rt_left' if name == 'LEFT$' else 'call rt_right')
            self.tmp = True
            return 'S'
        if name == 'MID$':
            ts = self.args(2, 3)
            self.want('S', ts[0])
            self.want('I', ts[1])
            if len(ts) == 3:
                self.want('I', ts[2])
                e('pop de')
                e('pop bc')
            else:
                e('ex de,hl')
                e('pop bc')
                e('ld hl,255')
            e('call rt_mid')
            self.tmp = True
            return 'S'
        if name == 'INKEY$':
            e('call rt_inkey')
            self.tmp = True
            return 'S'
        if name == 'TIMER':
            e('ld hl,(JIFFY)')
            return 'I'
        return None

    def user_call(self, f, want_value):
        n = len(f.params)
        if n:
            self.expect_p('(')
            for i, (pn, pt) in enumerate(f.params):
                if i:
                    self.expect_p(',')
                self.want(pt, self.expr())
                self.emit('push hl')
            self.expect_p(')')
        elif self.accept_p('('):
            self.expect_p(')')
        self.emit(f'call {f.label}')
        if n:
            if want_value:
                self.emit('ex de,hl')
            self.emit(f'ld hl,{2 * n}')
            self.emit('add hl,sp')
            self.emit('ld sp,hl')
            if want_value:
                self.emit('ex de,hl')
        if want_value and f.ret == 'S':
            self.tmp = True
        return f.ret

    def primary(self):
        t = self.next()
        k, v = t
        if k == 'N':
            self.emit(f'ld hl,{v & 0xFFFF}')
            return 'I'
        if k == 'S':
            if v == '':
                self.emit('ld hl,rt_empty')
            else:
                self.emit(f'ld hl,{self.strlit(v)}')
            return 'S'
        if k == 'P' and v == '(':
            ty = self.expr()
            self.expect_p(')')
            return ty
        if k == 'I':
            if v in self.consts:
                self.emit(f'ld hl,{self.consts[v] & 0xFFFF}')
                return 'I'
            if v in self.funcs and self.funcs[v].kind == 'FUNCTION' and not (
                    self.cur and self.cur.name == v and not self.is_p('(')):
                return self.user_call(self.funcs[v], True)
            if v in self.arrays and self.is_p('('):
                self.array_addr(v)
                self.emit('ld e,(hl)')
                self.emit('inc hl')
                self.emit('ld d,(hl)')
                self.emit('ex de,hl')
                return 'I'
            b = self.builtin(v)
            if b:
                return b
            if self.cur and self.cur.kind == 'FUNCTION' and self.cur.name == v:
                return self.load_var(v)
            return self.load_var(v)
        self.err("espressione non valida")

    def array_addr(self, name):
        lab, count = self.arrays[name]
        self.expect_p('(')
        self.want('I', self.expr())
        self.expect_p(')')
        self.emit(f'ld de,{count}')
        self.emit('call rt_chk')
        self.emit('add hl,hl')
        self.emit(f'ld de,{lab}')
        self.emit('add hl,de')

    # ------------------------------------------------------------ statement
    def with_temps(self, fn):
        """esegue fn() e, se ha creato stringhe temporanee, rilascia lo heap"""
        old = self.tmp
        self.tmp = False
        start = len(self.code)
        fn()
        if self.tmp:
            self.code[start:start] = ['        ld hl,(heapp)', '        push hl']
            self.emit('pop de')
            self.emit('ld (heapp),de')
        self.tmp = old

    def cond_jz(self, target):
        """valuta la condizione e salta a target se falsa"""
        def f():
            self.want('I', self.expr())
        self.with_temps(f)
        self.emit('ld a,h')
        self.emit('or l')
        self.emit(f'jp z,{target}')

    def parse_stmts_until_end(self):
        while not self.at_end() and not self.is_kw('ELSE'):
            self.statement()
            if not self.accept_p(':'):
                break

    def fail(self, lineno, msg):
        self.lineno = lineno
        self.err(msg)

    def program_lines(self):
        """[(lineno, toks)] nell'ordine di compilazione, applicando la modalita'
        (OPTION NUMBERED | LABELS | MIXED)"""
        src = [(i, lex(ln, i)) for i, ln in enumerate(self.lines, 1)]
        src = [(i, tk) for i, tk in src if tk]

        def body(tk):
            return tk[1:] if tk[0][0] == 'N' else tk
        for i, tk in src:
            b = body(tk)
            if b[:1] == [('I', 'OPTION')]:
                if len(b) != 2 or b[1][0] != 'I' or b[1][1].lower() not in MODES:
                    self.fail(i, "OPTION NUMBERED | LABELS | MIXED")
                self.mode = b[1][1].lower()
        if self.mode == 'numbered':
            seen, rows = {}, []
            for i, tk in src:
                if body(tk)[:1] == [('I', 'OPTION')]:
                    continue
                if tk[0][0] != 'N':
                    self.fail(i, "modalita' NUMBERED: manca il numero di riga")
                n = tk[0][1]
                if n in seen:
                    self.fail(i, f"numero di riga {n} duplicato (gia' alla riga {seen[n]})")
                seen[n] = i
                rows.append((n, i, tk))
            return [(i, tk) for n, i, tk in sorted(rows, key=lambda r: r[0])]
        if self.mode == 'labels':
            for i, tk in src:
                if tk[0][0] == 'N':
                    self.fail(i, "modalita' LABELS: i numeri di riga non sono ammessi")
        return src

    def compile(self):
        prog = self.program_lines()
        # prescan: firme di SUB/FUNCTION (forward reference)
        for i, tk in prog:
            if tk[0][0] == 'N':
                tk = tk[1:]
            if tk and tk[0][0] == 'I' and tk[0][1] in ('SUB', 'FUNCTION') and len(tk) > 1:
                self.lineno = i
                self.toks, self.pos = tk, 1
                name = self.ident()
                params = []
                if self.accept_p('('):
                    while not self.is_p(')'):
                        pn = self.ident()
                        params.append((pn, vtype(pn)))
                        if not self.accept_p(','):
                            break
                    self.expect_p(')')
                self.funcs[name] = Func(tk[0][1], name, params)
        self.label('main_start')
        for i, tk in prog:
            self.lineno = i
            self.toks = tk
            self.pos = 0
            if self.toks[0][0] == 'N':       # numero di riga = label
                self.defined.add(f'L_{self.toks[0][1]}')
                self.label(f'L_{self.toks[0][1]}')
                self.pos = 1
            self.line()
        if self.blocks:
            self.err(f"blocco {self.blocks[-1]['kind']} non chiuso")
        for lab, ln in self.refs:
            if lab not in self.defined:
                what = 'riga' if lab[2:].isdigit() else 'etichetta'
                self.fail(ln, f"{what} inesistente: {lab[2:]}")
        self.emit('jp rt_end')

    def line(self):
        while not self.at_end():
            # label "nome:"
            if (self.peek()[0] == 'I' and self.is_p(':', 1) and not self.is_stmt_kw(self.peek()[1])
                    and self.peek()[1] not in self.funcs):
                if self.mode == 'numbered':
                    self.err("modalita' NUMBERED: le etichette non sono ammesse")
                self.defined.add('L_' + self.peek()[1])
                self.label('L_' + self.peek()[1])
                self.pos += 2
                continue
            self.statement()
            if self.at_end():
                break
            if not self.accept_p(':'):
                self.err("fine istruzione attesa")

    STMT_KW = {'PRINT', 'LET', 'IF', 'ELSEIF', 'ELSE', 'END', 'FOR', 'NEXT', 'WHILE',
               'WEND', 'DO', 'LOOP', 'EXIT', 'GOTO', 'GOSUB', 'RETURN', 'SELECT',
               'CASE', 'SUB', 'FUNCTION', 'CALL', 'DECLARE', 'DIM', 'SHARED', 'CONST',
               'INPUT', 'CLS', 'LOCATE', 'COLOR', 'RANDOMIZE', 'POKE', 'VPOKE', 'OUT',
               'SLEEP', 'STOP', 'OPTION'}

    def is_stmt_kw(self, w):
        return w in self.STMT_KW

    def statement(self):
        t = self.peek()
        if t == ('P', '?'):
            self.next()
            return self.st_print()
        if t[0] != 'I':
            self.err("istruzione attesa")
        w = t[1]
        h = getattr(self, 'st_' + w.lower(), None) if w in self.STMT_KW else None
        if h:
            self.next()
            return h()
        # assegnamento o chiamata SUB senza CALL
        if w in self.funcs and self.funcs[w].kind == 'SUB':
            self.next()
            return self.call_sub(self.funcs[w])
        return self.st_assign()

    # --- assegnamento
    def st_let(self):
        self.st_assign()

    def st_assign(self):
        name = self.ident()
        if name in self.arrays and self.is_p('('):
            def f():
                self.array_addr(name)
                self.emit('push hl')
                self.expect_p('=')
                self.want('I', self.expr())
                self.emit('pop de')
                self.emit('ld a,l')
                self.emit('ld (de),a')
                self.emit('inc de')
                self.emit('ld a,h')
                self.emit('ld (de),a')
            self.with_temps(f)
            return

        def g():
            self.expect_p('=')
            self.want(vtype(name), self.expr())
            self.store_var(name)
        self.with_temps(g)

    # --- PRINT
    def st_print(self):
        def f():
            nl = True
            while not self.at_stmt_end():
                if self.accept_p(';'):
                    nl = False
                    continue
                if self.accept_p(','):
                    self.emit('call rt_zone')
                    nl = False
                    continue
                nl = True
                t = self.expr()
                self.emit('call rt_pint' if t == 'I' else 'call rt_pstr')
            if nl:
                self.emit('call rt_pnl')
        self.with_temps(f)

    def st_input(self):
        def f():
            nl_q = True
            if self.peek()[0] == 'S':
                s = self.next()[1]
                self.emit(f'ld hl,{self.strlit(s) if s else "rt_empty"}')
                self.emit('call rt_pstr')
                if self.accept_p(','):
                    nl_q = False
                else:
                    self.expect_p(';')
            if nl_q:
                self.emit(f'ld hl,{self.strlit("? ")}')
                self.emit('call rt_pstr')
            name = self.ident()
            self.emit('call rt_input')
            self.tmp = True
            if vtype(name) == 'I':
                self.emit('call rt_val')
            self.store_var(name)
        self.with_temps(f)

    def st_cls(self):
        self.emit('call rt_cls')

    def st_locate(self):
        def f():
            self.want('I', self.expr())
            self.expect_p(',')
            self.emit('push hl')
            self.want('I', self.expr())
            self.emit('pop de')
            self.emit('ld h,l')
            self.emit('ld l,e')
            self.emit('call POSIT')
        self.with_temps(f)

    def st_color(self):
        def f():
            self.want('I', self.expr())
            self.emit('push hl')
            if self.accept_p(','):
                self.want('I', self.expr())
            else:
                self.emit('ld hl,(BAKCLR-1)')
                self.emit('ld l,h')
            self.emit('pop de')
            self.emit('call rt_color')
        self.with_temps(f)

    def st_randomize(self):
        self.want('I', self.expr())
        lab = self.newlab()
        self.emit('ld a,h')
        self.emit('or l')
        self.emit(f'jr nz,{lab}')
        self.emit('inc hl')
        self.label(lab)
        self.emit('ld (rndseed),hl')

    def two_args(self):
        self.want('I', self.expr())
        self.expect_p(',')
        self.emit('push hl')
        self.want('I', self.expr())
        self.emit('pop de')

    def st_poke(self):
        self.two_args()
        self.emit('ld a,l')
        self.emit('ld (de),a')

    def st_vpoke(self):
        self.two_args()
        self.emit('ld a,l')
        self.emit('ex de,hl')
        self.emit('call WRTVRM')

    def st_out(self):
        self.two_args()
        self.emit('ld c,e')
        self.emit('ld a,l')
        self.emit('out (c),a')

    def st_sleep(self):
        self.want('I', self.expr())
        self.emit('call rt_wait')

    def st_stop(self):
        self.emit('jp rt_end')

    def st_declare(self):
        self.pos = len(self.toks)

    def st_const(self):
        while True:
            name = self.ident()
            self.expect_p('=')
            neg = self.accept_p('-')
            t = self.next()
            if t[0] != 'N':
                self.err("CONST richiede un numero")
            self.consts[name] = -t[1] if neg else t[1]
            if not self.accept_p(','):
                break

    def st_dim(self):
        while True:
            name = self.ident()
            if self.accept_p('('):
                if vtype(name) == 'S':
                    self.err("array di stringhe non supportati (v0)")
                t = self.next()
                if t[0] != 'N':
                    self.err("DIM richiede dimensione costante")
                self.expect_p(')')
                if self.cur:
                    self.err("DIM di array solo a livello globale (v0)")
                lab = 'a_' + sym(name)
                self.arrays[name] = (lab, t[1] + 1)
                self.gsize_arrays = getattr(self, 'gsize_arrays', [])
                self.gsize_arrays.append((lab, t[1] + 1))
            else:
                self.resolve(name)
            if not self.accept_p(','):
                break

    def st_shared(self):
        while True:
            name = self.ident()
            if self.cur:
                self.cur.shared.add(name)
            if not self.accept_p(','):
                break

    # --- salti
    def st_goto(self):
        self.emit(f'jp {self.target()}')

    def st_gosub(self):
        self.emit(f'call {self.target()}')

    def st_return(self):
        self.emit('ret')

    def target(self):
        t = self.next()
        if t[0] == 'N':
            if self.mode == 'labels':
                self.err("modalita' LABELS: usa un'etichetta, non un numero di riga")
        elif t[0] == 'I':
            if self.mode == 'numbered':
                self.err("modalita' NUMBERED: usa un numero di riga, non un'etichetta")
        else:
            self.err("etichetta o numero di riga atteso")
        lab = f'L_{t[1]}'
        self.refs.append((lab, self.lineno))
        return lab

    def is_goto_target(self):
        """dopo THEN/ELSE: numero di riga, oppure etichetta nuda (IF x THEN fine)"""
        t = self.peek()
        if t[0] == 'N':
            return True
        if t[0] != 'I' or self.is_stmt_kw(t[1]) or t[1] in self.funcs:
            return False
        return self.peek(1)[0] == 'E' or self.peek(1) in (('P', ':'), ('I', 'ELSE'))

    def st_option(self):
        self.pos = len(self.toks)

    # --- IF
    def st_if(self):
        els = self.newlab()
        self.cond_jz(els)
        self.expect_kw('THEN')
        if self.at_end():                          # forma a blocchi
            self.blocks.append({'kind': 'IF', 'else': els, 'end': self.newlab()})
            return
        end = self.newlab()
        if self.is_goto_target():
            self.emit(f'jp {self.target()}')
        else:
            self.parse_stmts_until_end()
        if self.accept_kw('ELSE'):
            self.emit(f'jp {end}')
            self.label(els)
            if self.is_goto_target():
                self.emit(f'jp {self.target()}')
            else:
                self.parse_stmts_until_end()
        else:
            self.label(els)
        self.label(end)

    def blk(self, kind):
        if not self.blocks or self.blocks[-1]['kind'] != kind:
            self.err(f"{kind} senza blocco corrispondente")
        return self.blocks[-1]

    def st_elseif(self):
        b = self.blk('IF')
        self.emit(f'jp {b["end"]}')
        self.label(b['else'])
        b['else'] = self.newlab()
        self.cond_jz(b['else'])
        self.expect_kw('THEN')

    def st_else(self):
        b = self.blk('IF')
        self.emit(f'jp {b["end"]}')
        self.label(b['else'])
        b['else'] = None

    # --- FOR/NEXT
    def st_for(self):
        name = self.ident()
        self.want('I', 'I' if vtype(name) == 'I' else 'S')
        self.expect_p('=')

        def init():
            self.want('I', self.expr())
            self.store_var(name)
        self.with_temps(init)
        self.expect_kw('TO')
        self.with_temps(lambda: self.want('I', self.expr()))
        self.emit('push hl')
        step = 1
        if self.accept_kw('STEP'):
            neg = self.accept_p('-')
            t = self.next()
            if t[0] != 'N':
                self.err("STEP deve essere una costante (v0)")
            step = -t[1] if neg else t[1]
        top, ex, nxt = self.newlab(), self.newlab(), self.newlab()
        self.label(top)
        self.emit('pop de')
        self.emit('push de')
        self.load_var(name)
        self.emit('ex de,hl')
        self.emit('call rt_cmp')
        if step >= 0:
            ok = self.newlab()
            self.emit(f'jr c,{ok}')
            self.emit(f'jp nz,{ex}')
            self.label(ok)
        else:
            self.emit(f'jp c,{ex}')
        self.blocks.append({'kind': 'FOR', 'var': name, 'step': step,
                            'top': top, 'exit': ex, 'next': nxt})

    def st_next(self):
        b = self.blk('FOR')
        self.blocks.pop()
        if self.peek()[0] == 'I' and self.peek()[1] == b['var']:
            self.next()
        self.label(b['next'])
        self.load_var(b['var'])
        self.emit(f'ld de,{b["step"] & 0xFFFF}')
        self.emit('add hl,de')
        self.store_var(b['var'])
        self.emit(f'jp {b["top"]}')
        self.label(b['exit'])
        self.emit('pop de')

    # --- WHILE / DO
    def st_while(self):
        top, ex = self.newlab(), self.newlab()
        self.label(top)
        self.cond_jz(ex)
        self.blocks.append({'kind': 'WHILE', 'top': top, 'exit': ex, 'next': top})

    def st_wend(self):
        b = self.blk('WHILE')
        self.blocks.pop()
        self.emit(f'jp {b["top"]}')
        self.label(b['exit'])

    def st_do(self):
        top, ex = self.newlab(), self.newlab()
        self.label(top)
        if self.is_kw('WHILE') or self.is_kw('UNTIL'):
            until = self.next()[1] == 'UNTIL'
            if until:
                ok = self.newlab()
                self.with_temps(lambda: self.want('I', self.expr()))
                self.emit('ld a,h')
                self.emit('or l')
                self.emit(f'jp nz,{ex}')
            else:
                self.cond_jz(ex)
        self.blocks.append({'kind': 'DO', 'top': top, 'exit': ex, 'next': top})

    def st_loop(self):
        b = self.blk('DO')
        self.blocks.pop()
        if self.is_kw('WHILE') or self.is_kw('UNTIL'):
            until = self.next()[1] == 'UNTIL'
            self.with_temps(lambda: self.want('I', self.expr()))
            self.emit('ld a,h')
            self.emit('or l')
            self.emit(f'jp {"z" if until else "nz"},{b["top"]}')
        else:
            self.emit(f'jp {b["top"]}')
        self.label(b['exit'])

    def st_exit(self):
        w = self.ident()
        if w in ('SUB', 'FUNCTION'):
            if not self.cur:
                self.err("EXIT fuori da SUB/FUNCTION")
            self.emit(f'jp {self.cur.exit}')
            return
        for b in reversed(self.blocks):
            if b['kind'] == w:
                self.emit(f'jp {b["exit"]}')
                return
        self.err(f"EXIT {w} fuori da un blocco {w}")

    # --- SELECT CASE
    def st_select(self):
        self.expect_kw('CASE')
        self.with_temps(lambda: self.want('I', self.expr()))
        self.emit('push hl')
        self.blocks.append({'kind': 'SELECT', 'end': self.newlab(), 'next': None})

    def st_case(self):
        b = self.blk('SELECT')
        if b['next']:
            self.emit(f'jp {b["end"]}')
            self.label(b['next'])
        b['next'] = None
        if self.accept_kw('ELSE'):
            return
        nxt, body = self.newlab(), self.newlab()
        while True:
            if self.accept_kw('IS'):
                op = self.next()
                if op[0] != 'P' or op[1] not in BOOL_CALL:
                    self.err("operatore atteso dopo IS")
                self.want('I', self.expr())
                self.emit('pop de')
                self.emit('push de')
                self.emit('call rt_cmp')
                self.emit(f'call {BOOL_CALL[op[1]]}')
                self.emit('ld a,h')
                self.emit('or l')
                self.emit(f'jp nz,{body}')
            else:
                self.want('I', self.expr())
                if self.accept_kw('TO'):
                    fail = self.newlab()
                    self.emit('pop de')
                    self.emit('push de')
                    self.emit('call rt_cmp')
                    self.emit(f'jp c,{fail}')
                    self.want('I', self.expr())
                    self.emit('pop de')
                    self.emit('push de')
                    self.emit('call rt_cmp')
                    self.emit(f'jp z,{body}')
                    self.emit(f'jp c,{body}')
                    self.label(fail)
                else:
                    self.emit('pop de')
                    self.emit('push de')
                    self.emit('call rt_cmp')
                    self.emit(f'jp z,{body}')
            if not self.accept_p(','):
                break
        self.emit(f'jp {nxt}')
        self.label(body)
        b['next'] = nxt

    # --- END ...
    def st_end(self):
        if self.at_stmt_end():
            self.emit('jp rt_end')
            return
        w = self.ident()
        if w == 'IF':
            b = self.blk('IF')
            self.blocks.pop()
            if b['else']:
                self.label(b['else'])
            self.label(b['end'])
        elif w == 'SELECT':
            b = self.blk('SELECT')
            self.blocks.pop()
            if b['next']:
                self.label(b['next'])
            self.label(b['end'])
            self.emit('pop de')
        elif w in ('SUB', 'FUNCTION'):
            self.end_func(w)
        else:
            self.err(f"END {w} sconosciuto")

    # --- SUB / FUNCTION
    def st_sub(self):
        self.begin_func('SUB')

    def st_function(self):
        self.begin_func('FUNCTION')

    def begin_func(self, kind):
        if self.cur:
            self.err("SUB/FUNCTION annidate")
        name = self.ident()
        f = self.funcs[name]
        self.pos = len(self.toks)
        self.cur = f
        f.exit = self.newlab('X')
        skip = self.newlab()
        f.skip = skip
        self.emit(f'jp {skip}')
        self.label(f.label)
        self.emit('push ix')
        self.emit('ld ix,0')
        self.emit('add ix,sp')
        self.emit(f'ld hl,-FRAME_{sym(name)}')
        self.emit('add hl,sp')
        self.emit('ld sp,hl')
        self.blocks.append({'kind': kind})
        if kind == 'FUNCTION':
            if f.ret == 'S':
                self.resolve(name)
                # la stringa risultato parte vuota
                kind_, off = self.resolve(name)
                self.ptr_local(off)
                self.emit('ld (hl),0')
            else:
                self.resolve(name)
                kind_, off = self.resolve(name)
                self.emit('ld hl,0')
                self.emit(f'ld (ix{off:+d}),l')
                self.emit(f'ld (ix{off + 1:+d}),h')

    def end_func(self, kind):
        b = self.blocks.pop() if self.blocks else None
        f = self.cur
        if not b or b['kind'] != kind or not f or f.kind != kind:
            self.err(f"END {kind} inatteso")
        self.label(f.exit)
        if kind == 'FUNCTION':
            kd, off = self.resolve(f.name)
            if f.ret == 'S':
                self.ptr_local(off)
                self.emit('call rt_sdup')
            else:
                self.emit(f'ld l,(ix{off:+d})')
                self.emit(f'ld h,(ix{off + 1:+d})')
        self.emit('ld sp,ix')
        self.emit('pop ix')
        self.emit('ret')
        frame = 64 + 256 * f.nstr
        self.emit(f'; frame {f.name}')
        self.code.append(f'FRAME_{sym(f.name)} equ {frame}')
        self.label(f.skip)
        self.cur = None

    def st_call(self):
        name = self.ident()
        f = self.funcs.get(name)
        if not f or f.kind != 'SUB':
            self.err(f"SUB {name} sconosciuta")
        self.call_sub(f)

    def call_sub(self, f):
        def g():
            n = len(f.params)
            if n:
                paren = self.accept_p('(')
                for i, (pn, pt) in enumerate(f.params):
                    if i:
                        self.expect_p(',')
                    self.want(pt, self.expr())
                    self.emit('push hl')
                if paren:
                    self.expect_p(')')
            elif self.accept_p('('):
                self.expect_p(')')
            self.emit(f'call {f.label}')
            if n:
                self.emit(f'ld hl,{2 * n}')
                self.emit('add hl,sp')
                self.emit('ld sp,hl')
        self.with_temps(g)

    # ------------------------------------------------------------ output
    def output(self):
        out = ['        INCLUDE "runtime.asm"']
        out += self.code
        for text, lab in self.lits.items():
            data = ','.join(str(ord(c) & 0xFF) for c in text)
            out.append(f'{lab}: db {len(text)}' + (',' + data if data else ''))
        # variabili globali (EQU)
        addr = 0
        for name, off in self.gvars.items():
            out.append(f'v_{sym(name)} equ DATA_BASE+{off}')
        addr = self.gsize
        for lab, count in getattr(self, 'gsize_arrays', []):
            out.append(f'{lab} equ DATA_BASE+{addr}')
            addr += 2 * count
        out.append(f'HEAPBASE equ DATA_BASE+{addr + 2}')
        out.append('        ds 04000h+4000h-$,0FFh      ; ROM 16K')
        out.append('        SAVEBIN "out.rom",4000h,4000h')
        return '\n'.join(out) + '\n'


def compile_source(src, mode='mixed'):
    c = Compiler(src, mode)
    c.compile()
    return c.output()


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("uso: qbc.py input.bas output.asm [numbered|labels|mixed]")
        sys.exit(1)
    try:
        asm = compile_source(open(sys.argv[1], encoding='latin-1').read(),
                             sys.argv[3] if len(sys.argv) > 3 else 'mixed')
    except CompileError as e:
        print("ERRORE:", e)
        sys.exit(2)
    open(sys.argv[2], 'w', encoding='latin-1', newline='\n').write(asm)
