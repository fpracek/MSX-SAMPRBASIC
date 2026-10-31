; le cartucce non hanno la virgola mobile (il runtime non entrerebbe nel segmento fisso): tutte le voci danno errore
msg_nofl: db msg_nofl_e-msg_nofl-1,"Error: No floating point in ROM"
msg_nofl_e:
fp_itof:
fp_push:
fp_pop:
fp_ipop:
fp_add:
fp_sub:
fp_mul:
fp_div:
fp_cmp:
fp_neg:
rt_fpow:
rt_frnd:
rt_ftrunc:
fp_load:
fp_st:
rt_pflt:
rt_fstr:
rt_fval:
rt_fsqr:
rt_fsin:
rt_fcos:
rt_ftan:
rt_fatn:
rt_flog:
rt_fexp:
fp_abs:
rt_fsgn:
fp_int:
fp_fix:
rt_flit:
        ld hl,msg_nofl
        jp rt_fatal
