        IFNDEF RTB
        IFDEF ROMMODE
RTB       equ 4100h
        ELSE
        IFDEF BINMODE
RTB       equ 8400h             ; BIN: image at 8400h (BASIC with CLEAR 200,&H83FF)
        ELSE
RTB       equ 0100h
        ENDIF
        ENDIF
        ENDIF
; Runtime entry points (table of JPs at fixed addresses, image at 0100h)
RT_PSTR   equ RTB+(0103h-0100h)
RT_PINT   equ RTB+(0106h-0100h)
RT_PNL    equ RTB+(0109h-0100h)
RT_ZONE   equ RTB+(010Ch-0100h)
RT_CLS    equ RTB+(010Fh-0100h)
RT_LOCATE equ RTB+(0112h-0100h)
RT_MUL    equ RTB+(0115h-0100h)
RT_DIV    equ RTB+(0118h-0100h)
RT_MOD    equ RTB+(011Bh-0100h)
RT_CMP    equ RTB+(011Eh-0100h)
RT_BEQ    equ RTB+(0121h-0100h)
RT_BNE    equ RTB+(0124h-0100h)
RT_BLT    equ RTB+(0127h-0100h)
RT_BGT    equ RTB+(012Ah-0100h)
RT_BLE    equ RTB+(012Dh-0100h)
RT_BGE    equ RTB+(0130h-0100h)
RT_END    equ RTB+(0133h-0100h)
RT_NEG    equ RTB+(0136h-0100h)
RT_CHK    equ RTB+(0139h-0100h)
RT_RND    equ RTB+(013Ch-0100h)
RT_SCOPY  equ RTB+(013Fh-0100h)
RT_SCAT   equ RTB+(0142h-0100h)
RT_SCMP   equ RTB+(0145h-0100h)
RT_LEFT   equ RTB+(0148h-0100h)
RT_RIGHT  equ RTB+(014Bh-0100h)
RT_MID    equ RTB+(014Eh-0100h)
RT_LEN    equ RTB+(0151h-0100h)
RT_ASC    equ RTB+(0154h-0100h)
RT_CHR    equ RTB+(0157h-0100h)
RT_STR    equ RTB+(015Ah-0100h)
RT_VAL    equ RTB+(015Dh-0100h)
RT_INKEY  equ RTB+(0160h-0100h)
RT_INPUT  equ RTB+(0163h-0100h)
RT_SDUP   equ RTB+(0166h-0100h)
RT_COLOR  equ RTB+(0169h-0100h)
RT_WAIT   equ RTB+(016Ch-0100h)
RT_VPEEK  equ RTB+(016Fh-0100h)
RT_VPOKE  equ RTB+(0172h-0100h)
RT_SCREEN equ RTB+(0175h-0100h)
RT_GPSET  equ RTB+(0178h-0100h)
RT_GPRESET equ RTB+(017Bh-0100h)
RT_GPOINT equ RTB+(017Eh-0100h)
RT_GLINE  equ RTB+(0181h-0100h)
RT_GCIRCLE equ RTB+(0184h-0100h)
RT_PALETTE equ RTB+(0187h-0100h)
RT_PALINIT equ RTB+(018Ah-0100h)
RT_PAINT  equ RTB+(018Dh-0100h)
RT_SPRDEF equ RTB+(0190h-0100h)
RT_SPRPUT equ RTB+(0193h-0100h)
RT_SPRSIZE equ RTB+(0196h-0100h)
RT_GGET   equ RTB+(0199h-0100h)
RT_GPUT   equ RTB+(019Ch-0100h)
RT_DRAW   equ RTB+(019Fh-0100h)
RT_COLL   equ RTB+(01A2h-0100h)
RT_VIEW   equ RTB+(01A5h-0100h)
RT_VIEWR  equ RTB+(01A8h-0100h)
RT_WX     equ RTB+(01ABh-0100h)
RT_WY     equ RTB+(01AEh-0100h)
RT_WR     equ RTB+(01B1h-0100h)
RT_WINDOW equ RTB+(01B4h-0100h)
RT_WINRES equ RTB+(01B7h-0100h)
RT_VBANK  equ RTB+(01BAh-0100h)
RT_VFILL  equ RTB+(01BDh-0100h)
RT_VWRITE equ RTB+(01C0h-0100h)
RT_VREAD  equ RTB+(01C3h-0100h)
RT_BASE   equ RTB+(01C6h-0100h)
RT_VDP    equ RTB+(01C9h-0100h)
RT_VDPSET equ RTB+(01CCh-0100h)
RT_STICK  equ RTB+(01CFh-0100h)
RT_STRIG  equ RTB+(01D2h-0100h)
RT_SPRCOL equ RTB+(01D5h-0100h)
RT_SPRCOLS equ RTB+(01D8h-0100h)
RT_COPY   equ RTB+(01DBh-0100h)
RT_SETPAGE equ RTB+(01DEh-0100h)
RT_SCROLL equ RTB+(01E1h-0100h)
RT_READ   equ RTB+(01E4h-0100h)
RT_RESTORE equ RTB+(01E7h-0100h)
RT_BEEP   equ RTB+(01EAh-0100h)
RT_SOUND  equ RTB+(01EDh-0100h)
RT_PLAY   equ RTB+(01F0h-0100h)
RT_OPEN   equ RTB+(01F3h-0100h)
RT_CLOSE  equ RTB+(01F6h-0100h)
RT_OUTSEL equ RTB+(01F9h-0100h)
RT_FINPUT equ RTB+(01FCh-0100h)
RT_FLINE  equ RTB+(01FFh-0100h)
RT_FEOF   equ RTB+(0202h-0100h)
RT_KILL   equ RTB+(0205h-0100h)
RT_WINT   equ RTB+(0208h-0100h)
RT_WSTR   equ RTB+(020Bh-0100h)
RT_FARCALL equ RTB+(020Eh-0100h)
RT_SETBANK equ RTB+(0211h-0100h)
RT_DATAWIN equ RTB+(0214h-0100h)
RT_VCOPY  equ RTB+(0217h-0100h)
RT_MAPSEGS equ RTB+(021Ah-0100h)
RT_MGET   equ RTB+(021Dh-0100h)
RT_MPUT   equ RTB+(0220h-0100h)
RT_MREAD  equ RTB+(0223h-0100h)
RT_MWRITE equ RTB+(0226h-0100h)
RT_MALLOC equ RTB+(0229h-0100h)
RT_MFREE  equ RTB+(022Ch-0100h)
RT_MDIM   equ RTB+(022Fh-0100h)
RT_MAGET  equ RTB+(0232h-0100h)
RT_MAPUT  equ RTB+(0235h-0100h)
RT_BLOAD  equ RTB+(0238h-0100h)
RT_BSAVE  equ RTB+(023Bh-0100h)
RT_FIELD  equ RTB+(023Eh-0100h)
RT_FGET   equ RTB+(0241h-0100h)
RT_FPUT   equ RTB+(0244h-0100h)
RT_FLOF   equ RTB+(0247h-0100h)
RT_MKI    equ RTB+(024Ah-0100h)
RT_CVI    equ RTB+(024Dh-0100h)
RT_RSET   equ RTB+(0250h-0100h)
RT_EMPTY  equ RTB+(0253h-0100h)             ; byte 0 (empty string)
RT_NAME   equ RTB+(0254h-0100h)             ; 16 bytes: source name (0-terminated)
RT_DSIZE  equ RTB+(0264h-0100h)             ; word: program data bytes (written by the compiler)
RT_DATA0  equ RTB+(0266h-0100h)             ; word: first DATA item (0 = no DATA)
RT_TARGET equ RTB+(0268h-0100h)             ; byte: cartridge type (1 ROM16, 2 ROM32, 3 ASCII8, 4 ASCII16, 5 KONAMI, 6 SCC)
RT_DBG    equ RT_TARGET+1       ; jp rt_dbg: debugger hook (OPTION DEBUG)
RT_STAMP  equ RT_DBG+5          ; 20 bytes: date, time and variant of the build (the .COM compiler compares them)
RT_STAMPLEN equ 20
RT_SIZE   equ RT_DBG+3          ; word: size of the runtime image (read by the .COM compiler without reading the whole file)
        IFDEF BINMODE
RTRAM     equ 0D000h            ; BIN: runtime RAM and program data above the image
        ELSE
RTRAM     equ 0C090h            ; Runtime RAM (C000h-C086h: loader)
        ENDIF
HEAPP     equ RTRAM+0
HEAP0     equ RTRAM+10
GX1       equ RTRAM+118h        ; parametri grafici (word)
GY1       equ RTRAM+11Ah
GX2       equ RTRAM+11Ch
GY2       equ RTRAM+11Eh
GCOL      equ RTRAM+120h        ; colore (< 0 = colore corrente)
GFLG      equ RTRAM+122h        ; byte: 0 line, 1 box, 2 filled box
SCRMODE   equ RTRAM+123h        ; byte: current SCREEN mode
LASTX     equ RTRAM+124h        ; last graphic point
LASTY     equ RTRAM+126h
FONTPTR   equ RTRAM+150h        ; pointer to the 8x8 font (768 bytes at the top of the heap, reserved by SCREEN 5-8)
ROWPTR    equ RTRAM+152h        ; pointer to PAINT's pixel row (256 bytes at the top of the heap)
TCX       equ RTRAM+154h        ; text cursor in graphics (column, row)
TCY       equ RTRAM+155h
GBPP      equ RTRAM+156h        ; bits per pixel, pixels per byte, color mask
GPPB      equ RTRAM+157h
GONES     equ RTRAM+158h
GFGP      equ RTRAM+159h        ; colors replicated in a VRAM byte
GBGP      equ RTRAM+15Ah
PCOL      equ RTRAM+15Bh        ; PAINT: colore, bordo, tratto in corso
PBRD      equ RTRAM+15Ch
PRUN      equ RTRAM+15Dh
PSTK      equ RTRAM+15Eh        ; PAINT: seed stack and variables
PLIM      equ RTRAM+160h
PXS       equ RTRAM+162h
PY        equ RTRAM+164h
PXL       equ RTRAM+166h
PXR       equ RTRAM+168h
PX        equ RTRAM+16Ah
PSY       equ RTRAM+16Ch
PTX       equ RTRAM+16Eh
PTY       equ RTRAM+170h
ARRB      equ RTRAM+172h        ; GET/PUT array: base and number of elements
ARRC      equ RTRAM+174h
CCX       equ RTRAM+176h        ; CIRCLE arc/ellipse: center, last point
CCY       equ RTRAM+178h
CPX       equ RTRAM+17Ah
CPY       equ RTRAM+17Ch
DCOL      equ RTRAM+17Eh        ; DRAW: color, scale, B and N prefixes, length and pointer
DSC       equ RTRAM+17Fh
DB        equ RTRAM+180h
DN        equ RTRAM+181h
DLEN      equ RTRAM+182h
DPOS      equ RTRAM+183h
CRX       equ RTRAM+185h        ; CIRCLE: radii, current angle, degrees left, first point
CRY       equ RTRAM+187h
CANG      equ RTRAM+189h
CK        equ RTRAM+18Bh
CFIRST    equ RTRAM+18Dh
CEND      equ ARRB              ; CIRCLE: angolo finale (gradi) e aspetto (percentuale) riusano ARRB/ARRC
CASP      equ ARRC
GRPCOL    equ 0F3C9h            ; BIOS tables (SCREEN 2 colors and patterns, SCREEN 1-3 sprites)
GRPCGP    equ 0F3CBh
GRPATR    equ 0F3CDh
GRPPAT    equ 0F3CFh
T32ATR    equ 0F3C3h
T32PAT    equ 0F3C5h
MLTATR    equ 0F3D7h
MLTPAT    equ 0F3D9h
P2OFF     equ RTRAM+18Eh        ; SCREEN 2: pixel offset and mask (do not use S1..S8: they are needed by the callers)
P2MSK     equ RTRAM+190h
VX1       equ RTRAM+192h        ; VIEW: clipping window (limits inclusive) and its dimensions
VY1       equ RTRAM+194h
VX2       equ RTRAM+196h
VY2       equ RTRAM+198h
VXW       equ RTRAM+19Ah
VYH       equ RTRAM+19Ch
SCRREAL   equ RTRAM+19Eh        ; requested SCREEN number (SCRMODE is 2 also for SCREEN 4: same layout)
WACT      equ RTRAM+19Fh        ; WINDOW: active, y axis upward, logical origin, extents, factors
WYUP      equ RTRAM+1A0h
WWX1      equ RTRAM+1A1h
WWY1      equ RTRAM+1A3h
WDX       equ RTRAM+1A5h
WDY       equ RTRAM+1A7h
WMX       equ RTRAM+1A9h
WMY       equ RTRAM+1ABh
W4        equ RTRAM+1ADh        ; accumulatore a 32 bit
WMU       equ RTRAM+1B1h
WDV       equ RTRAM+1B3h
WREM      equ RTRAM+1B5h
WCNT      equ RTRAM+1B7h
WSG       equ RTRAM+1B8h
UBANK     equ RTRAM+1B9h        ; VBANK: 64 KB of VRAM used by VPOKE/VPEEK/VFILL/VWRITE/VREAD
VA16      equ RTRAM+1BAh        ; A16 usato da vram_set
APAGE     equ RTRAM+1BBh        ; pagina attiva (SET PAGE)
GOP       equ RTRAM+1BCh        ; logical operator of the VDP commands
DPTR      equ RTRAM+1BDh        ; DATA/READ pointer
APY       equ RTRAM+1BFh        ; active page: Y offset (page*256) for the VDP commands
APLO      equ RTRAM+1C1h        ; ... VRAM address offset (low 16 bits)
APHI      equ RTRAM+1C3h        ; ... A16 of the VRAM address
CSP       equ RTRAM+1C4h        ; COPY: source page, destination (x,y), destination page (-1 = active)
CDX       equ RTRAM+1C6h
CDY       equ RTRAM+1C8h
CDP       equ RTRAM+1CAh
PLV       equ RTRAM+1CCh        ; PLAY: strings of the 3 voices
PVOICE    equ RTRAM+1D2h        ; PLAY: voice state (3 x 12 bytes)
PHZ       equ RTRAM+1F6h        ; PLAY: frame rate * 240
PTEMPO    equ RTRAM+1F8h
PANY      equ RTRAM+1FAh
FILEP     equ RTRAM+1FBh        ; file descriptors (0 = not yet reserved)
OUTSEL    equ RTRAM+1FDh        ; PRINT# file (0 = screen)
FARSP     equ RTRAM+1FEh        ; ROM: software stack of cross-segment calls
CURBANK   equ RTRAM+200h        ; ROM: bank in the code window
CWREG     equ RTRAM+201h        ; ROM: bank register of the code window
DWREG     equ RTRAM+203h        ; ROM: bank register of the data window (A000h for the 8 KB banks)
MSAVE     equ RTRAM+205h        ; mapper: page 2 segment to restore
MAPN      equ RTRAM+206h        ; number of segments (word), valid if MAPK <> 0
MAPK      equ RTRAM+208h
MT0       equ RTRAM+209h        ; detection scratch
MTN       equ RTRAM+20Ah
MTB       equ RTRAM+20Bh
MJT       equ RTRAM+20Ch        ; table of the mapper routines (DOS 2)
MALN      equ RTRAM+20Eh        ; segments taken from the top (without DOS 2)
RAMSL     equ RTRAM+20Fh        ; ROM: RAM slot (page 3 = mapper)
DBGP      equ RTRAM+210h        ; debugger: state block (at the top of the heap), 0 = not yet created
KUT       equ RTRAM+216h        ; JIFFY at the start of the wait for key release
M2FLAG    equ RTRAM+214h        ; 0 = MSX1 (TMS9918: no R#14, no 80 columns), otherwise MSX2 or higher
DBGT      equ RTRAM+212h        ; debugger: variable table (written by the program)
        IFDEF BINMODE
DATA_BASE equ RTRAM+0220h
        ELSE
DATA_BASE equ 0C2B0h
        ENDIF
