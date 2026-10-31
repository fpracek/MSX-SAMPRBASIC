import re,zrun,collections,sys
syms={}
for l in open('build/qbc.sym'):
    m=re.match(r'(\S+): EQU 0x([0-9A-F]+)',l)
    if m: syms[m.group(1)]=int(m.group(2),16)
inv=sorted((v,k) for k,v in syms.items())
def nm(pc):
    c=[(v,k) for v,k in inv if v<=pc][-1]; return '%s+%d'%(c[1],pc-c[0])
name=sys.argv[1]; target=sys.argv[2]
src=open('qtests/%s.bas'%name).read()
qbc=open('build/qbc.com','rb').read()
ms=zrun.Msx({'T.BAS':src.replace('\n','\r\n').encode()})
ms.boot(qbc,'T.BAS')
h=collections.deque(maxlen=int(sys.argv[3]) if len(sys.argv)>3 else 200)
m=ms.m
for step in range(6_000_000):
    m.ticks_to_stop=1
    ev=m.run()
    pc=m.pc
    h.append(pc)
    if ev&2:
        if pc==zrun.BDOS_STUB: ms.bdos()
        elif pc==zrun.CALSLT: ms.bios()
    if pc==syms[target]: break
out=[];last=None
for pc in h:
    n=nm(pc).split('+')[0]
    if n!=last: out.append(nm(pc)); last=n
print(out)
