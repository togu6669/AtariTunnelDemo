"""
gen_title.py  –  generates 'der_tunnel.asm' gothic title screen

Output: der_tunnel.asm   (ANTIC mode F, 320x192, mono)

Run:  python gen_title.py
"""

def row(s):
    """Convert a string of '#' and '.' to an integer (MSB = leftmost pixel)."""
    assert len(s) == 24, f"expected 24 chars, got {len(s)}: {s!r}"
    v = 0
    for ch in s:
        v = (v << 1) | (1 if ch == '#' else 0)
    return v

from gothic_capital import FONT_D, FONT_T
from gothic_small   import FONT_e, FONT_r, FONT_u, FONT_n, FONT_l

# --- space ---
FONT_SPC = [row('........................')] * 32

# ---------------------------------------------------------------------------
# Layout
#   Screen:  320 x 192 pixels  =  40 bytes x 192 rows
#   Text:    "Der Tunnel"  = D e r SPC T u n n e l  (10 chars)
#            24px each  → 240px = 30 bytes
#   H-centre: left byte = (40 - 30) // 2 = 5
#   V-centre: top row  = (192 - 32) // 2 = 80  → rows 80..111
# ---------------------------------------------------------------------------

SCREEN_W  = 40
SCREEN_H  = 192
CHAR_W_PX = 24
CHAR_H    = 32
NUM_CHARS = 10
TEXT_BYTE_W = NUM_CHARS * CHAR_W_PX // 8   # = 30 bytes

LEFT_BYTE = (SCREEN_W - TEXT_BYTE_W) // 2  # = 5
TOP_ROW   = (SCREEN_H - CHAR_H) // 2       # = 80

TEXT = [FONT_D, FONT_e, FONT_r, FONT_SPC,
        FONT_T, FONT_u, FONT_n, FONT_n, FONT_e, FONT_l]

# Build screen array
screen = bytearray(SCREEN_W * SCREEN_H)

for ci, glyph in enumerate(TEXT):
    char_byte_start = LEFT_BYTE + ci * 3      # 3 bytes per char (24px)
    for row_i, row_val in enumerate(glyph):
        screen_row = TOP_ROW + row_i
        base = screen_row * SCREEN_W + char_byte_start
        screen[base]   = (row_val >> 16) & 0xFF
        screen[base+1] = (row_val >>  8) & 0xFF
        screen[base+2] =  row_val        & 0xFF

# Decorative horizontal rules above and below text
for rule_row in (TOP_ROW - 4, TOP_ROW + CHAR_H + 3):
    base = rule_row * SCREEN_W
    for b in range(SCREEN_W):
        screen[base + b] = 0xAA if b % 2 == 0 else 0x55

# ---------------------------------------------------------------------------
# Emit der_tunnel.asm  (only the non-zero band to keep file size down)
# ---------------------------------------------------------------------------

band_rows  = TOP_ROW - 6
band_end   = TOP_ROW + CHAR_H + 6
band       = screen[band_rows * SCREEN_W : band_end * SCREEN_W]
band_pages = len(band) // 256
band_rem   = len(band) %  256
dest_addr  = f"TITLE_SCRN + {band_rows} * 40"

def bytes_as_mads(data, indent='        '):
    lines = []
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        line = indent + '.BYTE ' + ','.join(f'${b:02X}' for b in chunk)
        lines.append(line)
    return '\n'.join(lines)

asm = f"""; =============================================================================
; der_tunnel.asm  –  "Der Tunnel" gothic title screen
; ANTIC mode F (320x192 monochrome, 1 bpp)
;
; Standalone:  mads.exe der_tunnel.asm -o:build/der_tunnel.xex
; Integrated:  icl "der_tunnel.asm"  in tunnel.asm  (ORG below is kept)
;
; Public entry point:
;   JSR SHOW_TITLE   – displays title, waits for any key, then returns.
;                      Saves and restores the caller's display list.
;
; Memory reserved:
;   TITLE_SCRN  = $6010 .. $7E0F   (7680 bytes, screen RAM)
;   TITLE_DLIST = $5F00 .. $5FCF   (display list, ~207 bytes)
;
; TITLE_SCRN starts at $6010 (not $6000) so that row 102 lands exactly at
; $7000 ($6010 + 102*40 = $7000), avoiding an ANTIC 4K boundary wrap.
;
; To add to tunnel.asm:
;   1.  icl "der_tunnel.asm"   anywhere after  ORG $2400
;   2.  JSR SHOW_TITLE          at the top of START, before the MAIN loop
; =============================================================================

        ORG $3800           ; safe standalone address; keep when icl'd

TITLE_SCRN  = $6010
TITLE_DLIST = $5F00

SDLSTL   = $0230
SDLSTH   = $0231
CH       = $02FC

_DL_SAVE_L .BYTE 0
_DL_SAVE_H .BYTE 0

; ---------------------------------------------------------------------------
; SHOW_TITLE
; ---------------------------------------------------------------------------
SHOW_TITLE
        LDA SDLSTL
        STA _DL_SAVE_L
        LDA SDLSTH
        STA _DL_SAVE_H

        ; clear from $6000, 31 pages = $1F00 bytes (covers $6000..$7EFF)
        LDA #0
        STA $FA
        LDA #$60
        STA $FB
        LDA #0          ; restore A=0 after setting $FB
        LDY #0
        LDX #$1F
_CLR_PAGE
        STA ($FA),Y
        INY
        BNE _CLR_PAGE
        INC $FB
        DEX
        BNE _CLR_PAGE

        JSR _COPY_BAND
        JSR _BUILD_DLIST

        LDA #$0F            ; COLPF1 = white pixels
        STA $02C5
        LDA #$00            ; COLPF2 = black background
        STA $02C6
        LDA #$00
        STA $02C8

        LDA #<TITLE_DLIST
        STA SDLSTL
        LDA #>TITLE_DLIST
        STA SDLSTH

        LDA #$FF            ; clear keyboard buffer
        STA CH
_WAIT_KEY
        CMP CH              ; loop until CH != $FF (key pressed)
        BEQ _WAIT_KEY

        LDA _DL_SAVE_L
        STA SDLSTL
        LDA _DL_SAVE_H
        STA SDLSTH

        RTS

; ---------------------------------------------------------------------------
; _BUILD_DLIST  –  ANTIC mode-F DL at TITLE_DLIST
; 8 blank lines + 192 mode-F lines split at the 4K boundary ($7000):
;   line 0..101 from $6010  (102 lines * 40 = 4080 bytes → ends at $6FFF)
;   line 102..191 from $7000 ($6010 + 102*40 = $7000, no boundary crossing)
; ---------------------------------------------------------------------------
_BUILD_DLIST
        LDA #<TITLE_DLIST
        STA $FA
        LDA #>TITLE_DLIST
        STA $FB
        LDY #0

        LDA #$70            ; 8 blank scan-line instructions
        LDX #8
_BLD_BLK
        STA ($FA),Y
        INY
        DEX
        BNE _BLD_BLK

        LDA #$4F            ; first LMS: mode F from $6010
        STA ($FA),Y
        INY
        LDA #<TITLE_SCRN
        STA ($FA),Y
        INY
        LDA #>TITLE_SCRN
        STA ($FA),Y
        INY

        LDA #$0F            ; 101 mode-F lines (+ LMS line = 102)
        LDX #101
_BLD_F1
        STA ($FA),Y
        INY
        DEX
        BNE _BLD_F1

        LDA #$4F            ; second LMS at 4K boundary: $6010 + 102*40 = $7000
        STA ($FA),Y
        INY
        LDA #<(TITLE_SCRN+102*40)
        STA ($FA),Y
        INY
        LDA #>(TITLE_SCRN+102*40)
        STA ($FA),Y
        INY

        LDA #$0F            ; 89 mode-F lines (+ LMS line = 90; 102+90=192)
        LDX #89
_BLD_F2
        STA ($FA),Y
        INY
        DEX
        BNE _BLD_F2

        LDA #$41            ; JVB back to start of display list
        STA ($FA),Y
        INY
        LDA #<TITLE_DLIST
        STA ($FA),Y
        INY
        LDA #>TITLE_DLIST
        STA ($FA),Y

        RTS

; ---------------------------------------------------------------------------
; _COPY_BAND  –  copy {len(band)} bytes of pre-rendered text to screen RAM
; Source: _BAND_DATA   Dest: TITLE_SCRN + {band_rows}*40  (row {band_rows})
; {band_pages} full pages + {band_rem} remainder bytes
; ---------------------------------------------------------------------------
_COPY_BAND
        LDA #<_BAND_DATA
        STA $FA
        LDA #>_BAND_DATA
        STA $FB
        LDA #<({dest_addr})
        STA $FC
        LDA #>({dest_addr})
        STA $FD
        LDY #0
        LDX #{band_pages}
_CP_PAGE
        LDA ($FA),Y
        STA ($FC),Y
        INY
        BNE _CP_PAGE
        INC $FB
        INC $FD
        DEX
        BNE _CP_PAGE
        LDX #{band_rem}     ; remaining bytes
        BEQ _CP_DONE
_CP_REM
        LDA ($FA),Y
        STA ($FC),Y
        INY
        DEX
        BNE _CP_REM
_CP_DONE
        RTS

; ---------------------------------------------------------------------------
; _BAND_DATA  –  pre-rendered screen rows {band_rows}..{band_end-1}
; {len(band)} bytes  =  {len(band)//40} rows x 40 bytes
; ---------------------------------------------------------------------------
_BAND_DATA
{bytes_as_mads(band)}

; ---------------------------------------------------------------------------
; Standalone entry point  (remove JSR/JMP/RUNAD when icl'd into tunnel.asm)
; ---------------------------------------------------------------------------
DOSVEC  = $000A
_TITLE_MAIN
        JSR SHOW_TITLE
        JMP (DOSVEC)

        ORG $02E0
        .WORD _TITLE_MAIN
"""

out_path = 'der_tunnel.asm'
with open(out_path, 'w', encoding='utf-8') as f:
    f.write(asm)

print(f"Written {out_path}")
print(f"  Band: rows {band_rows}..{band_end-1}  ({len(band)} bytes = {band_pages} pages + {band_rem} bytes)")
print(f"  Text: rows {TOP_ROW}..{TOP_ROW+CHAR_H-1}, bytes {LEFT_BYTE}..{LEFT_BYTE+TEXT_BYTE_W-1}")
print(f"  Char cell: {CHAR_W_PX}x{CHAR_H}px")
