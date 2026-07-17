"""
gen_title.py  –  generates a gothic title screen .asm file

Usage:  python gen_title.py <text>
Output: <text_with_underscores>.asm  (ANTIC mode F, 320x192, mono)

Example: python gen_title.py "Der Tunnel"  ->  Der_Tunnel.asm
"""

import sys

def row(s):
    """Convert a string of '#' and '.' to an integer (MSB = leftmost pixel)."""
    assert len(s) == 24, f"expected 24 chars, got {len(s)}: {s!r}"
    v = 0
    for ch in s:
        v = (v << 1) | (1 if ch == '#' else 0)
    return v

import gothic_capital
import gothic_small

# Build font lookup from FONT_X attributes in both modules
font = {}
for _mod in (gothic_capital, gothic_small):
    for _name in dir(_mod):
        if _name.startswith('FONT_') and len(_name) == 6:
            font[_name[5]] = getattr(_mod, _name)
font[' '] = [row('........................')] * 32

# --- command-line argument ---
if len(sys.argv) < 2:
    print("Usage: python gen_title.py <text>")
    sys.exit(1)

text_str = sys.argv[1]
out_name = text_str.replace(' ', '_')
out_path = out_name + '.asm'

TEXT = []
for ch in text_str:
    if ch not in font:
        print(f"Error: no glyph for '{ch}'")
        sys.exit(1)
    TEXT.append(font[ch])

# ---------------------------------------------------------------------------
# Layout
#   Screen:  320 x 192 pixels  =  40 bytes x 192 rows
#   Each char: 24px wide = 3 bytes, 32px tall
# ---------------------------------------------------------------------------

SCREEN_W  = 40
SCREEN_H  = 192
CHAR_W_PX = 24
CHAR_H    = 32
NUM_CHARS = len(TEXT)
TEXT_BYTE_W = NUM_CHARS * CHAR_W_PX // 8
LEFT_BYTE = (SCREEN_W - TEXT_BYTE_W) // 2
TOP_ROW   = (SCREEN_H - CHAR_H) // 2

if LEFT_BYTE < 0:
    print(f"Error: text '{text_str}' is {TEXT_BYTE_W} bytes wide, exceeds screen width of {SCREEN_W}")
    sys.exit(1)

# Build screen array
screen = bytearray(SCREEN_W * SCREEN_H)

for ci, glyph in enumerate(TEXT):
    char_byte_start = LEFT_BYTE + ci * 3
    for row_i, row_val in enumerate(glyph):
        screen_row = TOP_ROW + row_i
        base = screen_row * SCREEN_W + char_byte_start
        screen[base]   = (row_val >> 16) & 0xFF
        screen[base+1] = (row_val >>  8) & 0xFF
        screen[base+2] =  row_val        & 0xFF

# Decorative horizontal rules above and below text
# for rule_row in (TOP_ROW - 4, TOP_ROW + CHAR_H + 3):
#     base = rule_row * SCREEN_W
#     for b in range(SCREEN_W):
#         screen[base + b] = 0xAA if b % 2 == 0 else 0x55

# ---------------------------------------------------------------------------
# Emit .asm  (only the non-zero band to keep file size down)
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
; {out_name}.asm  -  "{text_str}" gothic title screen
; ANTIC mode F (320x192 monochrome, 1 bpp)
;
; Standalone:  mads.exe {out_name}.asm -o:build/{out_name}.xex
; Integrated:  icl "{out_name}.asm"  in tunnel.asm  (ORG below is kept)
;
; Public entry point:
;   JSR SHOW_TITLE   - displays title, waits for any key, then returns.
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
;   1.  icl "{out_name}.asm"   anywhere after  ORG $2400
;   2.  JSR SHOW_TITLE          at the top of START, before the MAIN loop
; =============================================================================

        ORG $3800           ; safe standalone address; keep when icl'd

TITLE_SCRN  = $6010

SDLSTL   = $0230
SDLSTH   = $0231
SDMCTL   = $022F
CH       = $02FC
DMACTL   = $D400
DLISTL   = $D402
DLISTH   = $D403

_DL_SAVE_L .BYTE 0
_DL_SAVE_H .BYTE 0
_DMA_SAVE  .BYTE 0

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

        LDA #$0F            ; COLPF1 = white pixels
        STA $02C5
        LDA #$00            ; COLPF2 = black background
        STA $02C6
        LDA #$00
        STA $02C8

        LDA #<TITLE_DLIST
        STA SDLSTL
        STA DLISTL
        LDA #>TITLE_DLIST
        STA SDLSTH
        STA DLISTH

        LDA #$22
        STA SDMCTL
        STA DMACTL

        JSR FADE

        LDA #$FF            ; clear keyboard buffer
        STA CH

_WAIT_KEY
        CMP CH              ; loop until CH != $FF (key pressed)
        BEQ _WAIT_KEY

        LDA _DL_SAVE_L
        STA SDLSTL
        STA DLISTL
        LDA _DL_SAVE_H
        STA SDLSTH
        STA DLISTH
        LDA _DMA_SAVE
        STA SDMCTL
        STA DMACTL

        RTS

; -------------------------
; Display list: tryb bitmapowy 320x192, 2 kolory
; -------------------------

TITLE_DLIST
        .BYTE $4F, a($6010)   ; pierwsza linia z LMS
        :101 .BYTE $0F        ; kolejne linie 1..102

        .BYTE $4F, a($7000)   ; nowy LMS od linii 102
        :89 .BYTE $0F         ; kolejne linie 104..191

        .BYTE $41, a(TITLE_DLIST)

; ---------------------------------------------------------------------------
; _COPY_BAND  -  copy 1760 bytes of pre-rendered text to screen RAM
; Source: _BAND_DATA   Dest: TITLE_SCRN + 74*40  (row 74)
; 6 full pages + 224 remainder bytes
; ---------------------------------------------------------------------------
_COPY_BAND
        LDA #<_BAND_DATA
        STA $FA
        LDA #>_BAND_DATA
        STA $FB
        LDA #<(TITLE_SCRN + 74 * 40)
        STA $FC
        LDA #>(TITLE_SCRN + 74 * 40)
        STA $FD
        LDY #0
        LDX #6
_CP_PAGE
        LDA ($FA),Y
        STA ($FC),Y
        INY
        BNE _CP_PAGE
        INC $FB
        INC $FD
        DEX
        BNE _CP_PAGE
        LDX #224     ; remaining bytes
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
; _BAND_DATA  -  pre-rendered screen rows {band_rows}..{band_end-1}
; {len(band)} bytes  =  {len(band)//40} rows x 40 bytes
; ---------------------------------------------------------------------------
_BAND_DATA
{bytes_as_mads(band)}

        icl "Utils.asm"

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

with open(out_path, 'w', encoding='utf-8') as f:
    f.write(asm)

print(f"Written {out_path}")
print(f"  Text: '{text_str}'  ({NUM_CHARS} chars, {TEXT_BYTE_W} bytes wide)")
print(f"  Band: rows {band_rows}..{band_end-1}  ({len(band)} bytes = {band_pages} pages + {band_rem} bytes)")
print(f"  Placed: rows {TOP_ROW}..{TOP_ROW+CHAR_H-1}, bytes {LEFT_BYTE}..{LEFT_BYTE+TEXT_BYTE_W-1}")
print(f"  Char cell: {CHAR_W_PX}x{CHAR_H}px")
