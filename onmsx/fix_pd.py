s=open('patch_dim.py').read()
i=s.index("# guardie:")
j=s.index("new = '''arr_is_mapper")
good = r'''# guardie: gli array nel mapper si usano solo con x(i) in lettura/assegnamento
rep("        ld b,(hl)\n        ld a,b\n        or c\n        jp z,err_type\n        push de                 ; base\n",
    "        ld b,(hl)\n        bit 7,b\n        jp nz,err_type          ; array nel mapper: solo x(i) in lettura/assegnamento\n        ld a,b\n        or c\n        jp z,err_type\n        push de                 ; base\n")
rep("        ld b,(hl)\n        ld a,b\n        or c\n        jp z,err_type           ; non e' un array\n",
    "        ld b,(hl)\n        bit 7,b\n        jp nz,err_type\n        ld a,b\n        or c\n        jp z,err_type           ; non e' un array\n")
'''
open('patch_dim.py','w').write(s[:i]+good+s[j:])
