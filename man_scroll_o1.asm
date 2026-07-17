; man_scroll_o1.asm — Option 3: erase+redraw sprite each step (no ANTIC MSC wrap) - CLAUDE Crap 
;
; Fixed LMS: LMS1=$4010 (rows 0-101, $4000 page), LMS2=$5000 (rows 102-191, $5000 page).
; The two segments are contiguous in address space ($4FFF+1=$5000), so ROWPTR
; can walk straight through both without special-casing the boundary.
;
; Scroll DOWN: sprite starts at screen row 0, moves to row 72 (bottom of screen).
; Each step:
;   1. Erase old position: write 0 to SPR_H rows x SPR_W bytes at SCRPTR
;   2. SCRPTR += 40  (advance one row)
;   3. Redraw sprite: copy MAN_SPR -> SPR_H rows x SPR_W bytes at SCRPTR
;
; SCROLL_STEPS = TOTAL_ROWS - SPR_H = 192 - 120 = 72
; Timing: erase ~33k + draw ~47k = ~80k cycles/step; 3 VBLANKs = ~89k available.

; ── OS shadow registers ───────────────────────────────────────────────────────
SDMCTL   = $022F
DLISTL   = $0230
DLISTH   = $0231
COLOR0   = $02C4
COLOR1   = $02C5
COLOR2   = $02C6
COLOR3   = $02C7
COLOR4   = $02C8
RTCLOK60 = $0014

; ── Screen RAM (fixed LMS, never modified) ────────────────────────────────────
SCRN1       = $4010     ; LMS1: rows   0-101, $4010-$4FFF
SCRN2       = $5000     ; LMS2: rows 102-191, $5000-$5E0F
TOTAL_ROWS  = 192

; ── Sprite dimensions ─────────────────────────────────────────────────────────
SPR_W        = 24       ; bytes per sprite row
SPR_H        = 120      ; sprite rows
MAN_X0       = 8        ; byte-column offset (cols 8-31)
SCROLL_STEPS = 72       ; TOTAL_ROWS - SPR_H

; ── Zero-page variables ───────────────────────────────────────────────────────
    ORG $B0
MAN_X    .DS 1
MAN_YL   .DS 1
ACC_X    .DS 1
ACC_Y    .DS 1
FRAME    .DS 1
HOLD_CTR .DS 1
ROWPTR   .DS 2
SPRPTR   .DS 2
STEP_X   .DS 1
STEP_Y   .DS 1
SCRL_CTR .DS 1
SCRPTR   .DS 2          ; sprite top-left in screen RAM (column offset included)

; ── Main ──────────────────────────────────────────────────────────────────────
    ORG $2000

ANIM_MAIN
    LDA #$00
    STA SDMCTL

    LDA #<ANIM_DLIST
    STA DLISTL
    LDA #>ANIM_DLIST
    STA DLISTH

    LDA #$00
    STA COLOR0
    STA COLOR1
    STA COLOR3
    STA COLOR4
    LDA #$0F
    STA COLOR2

    JSR CLEAR_SCREEN

    ; SCRPTR = SCRN1 + MAN_X0 (sprite top-left at screen row 0)
    LDA #<(SCRN1 + MAN_X0)
    STA SCRPTR
    LDA #>(SCRN1 + MAN_X0)
    STA SCRPTR+1

    ; Initial draw: sprite at row 0
    LDA SCRPTR
    STA ROWPTR
    LDA SCRPTR+1
    STA ROWPTR+1
    LDA #<MAN_SPR
    STA SPRPTR
    LDA #>MAN_SPR
    STA SPRPTR+1
    JSR DRAW_SPR_FULL

    LDA #SCROLL_STEPS
    STA SCRL_CTR

    LDA #$22
    STA SDMCTL

loop
    LDX #2              ; wait 3 VBLANKs per step (~89k cycles budget)
_start
    LDA RTCLOK60
_wait
    CMP RTCLOK60
    BEQ _wait
    DEX
    BPL _start

    LDA SCRL_CTR
    BEQ loop            ; stop when sprite reaches bottom
    DEC SCRL_CTR
    JSR scroll_one_row
    JMP loop

; ── scroll_one_row ────────────────────────────────────────────────────────────
; Erase sprite at SCRPTR, advance SCRPTR one row (+40), redraw from MAN_SPR.
scroll_one_row:
    ; Pass 1: erase SPR_H rows x SPR_W bytes at SCRPTR
    LDA SCRPTR
    STA ROWPTR
    LDA SCRPTR+1
    STA ROWPTR+1
    LDX #SPR_H
@era_row:
    LDA #0
    LDY #(SPR_W-1)
@era_byte:
    STA (ROWPTR),Y
    DEY
    BPL @era_byte
    CLC
    LDA ROWPTR
    ADC #40
    STA ROWPTR
    BCC @era_nc
    INC ROWPTR+1
@era_nc:
    DEX
    BNE @era_row

    ; Advance SCRPTR one row
    CLC
    LDA SCRPTR
    ADC #40
    STA SCRPTR
    BCC @sp_nc
    INC SCRPTR+1
@sp_nc:

    ; Pass 2: draw sprite at new SCRPTR from MAN_SPR
    LDA SCRPTR
    STA ROWPTR
    LDA SCRPTR+1
    STA ROWPTR+1
    LDA #<MAN_SPR
    STA SPRPTR
    LDA #>MAN_SPR
    STA SPRPTR+1
    JSR DRAW_SPR_FULL
    RTS

; ── CLEAR_SCREEN ──────────────────────────────────────────────────────────────
; Zero 192 rows x 40 bytes from SCRN1 ($4010) through $5E0F.
CLEAR_SCREEN:
    LDA #<SCRN1
    STA ROWPTR
    LDA #>SCRN1
    STA ROWPTR+1
    LDA #0
    STA ACC_X
    LDX #0
@cs_row:
    LDA #0
    LDY #39
@cs_byte:
    STA (ROWPTR),Y
    DEY
    BPL @cs_byte
    CLC
    LDA ROWPTR
    ADC #40
    STA ROWPTR
    BCC @cs_nc
    INC ROWPTR+1
@cs_nc:
    INX
    BNE @cs_chk
    INC ACC_X
@cs_chk:
    CPX #<TOTAL_ROWS    ; $C0 (192 = $00C0, X never wraps)
    BNE @cs_row
    LDA ACC_X
    CMP #>TOTAL_ROWS    ; $00
    BNE @cs_row
    RTS

; ── DRAW_SPR_FULL ─────────────────────────────────────────────────────────────
; Copy SPR_H rows x SPR_W bytes from SPRPTR to ROWPTR (+40/row).
DRAW_SPR_FULL:
    LDX #SPR_H
@dsf_row:
    LDY #(SPR_W-1)
@dsf_byte:
    LDA (SPRPTR),Y
    STA (ROWPTR),Y
    DEY
    BPL @dsf_byte
    CLC
    LDA SPRPTR
    ADC #SPR_W
    STA SPRPTR
    BCC @dsf_s1
    INC SPRPTR+1
@dsf_s1:
    CLC
    LDA ROWPTR
    ADC #40
    STA ROWPTR
    BCC @dsf_s2
    INC ROWPTR+1
@dsf_s2:
    DEX
    BNE @dsf_row
    RTS

; ── Display list ──────────────────────────────────────────────────────────────
    ORG $2300
ANIM_DLIST
    .BYTE $70,$70,$70       ; 24 blank scan lines
    .BYTE $4E               ; mode $0E + LMS
    .WORD SCRN1             ; LMS1 = $4010 (fixed, within $4000 page)
    .REPT 101
    .BYTE $0E
    .ENDR
    .BYTE $4E               ; mode $0E + LMS
    .WORD SCRN2             ; LMS2 = $5000 (fixed, within $5000 page)
    .REPT 89
    .BYTE $0E
    .ENDR
    .BYTE $41               ; JVB
    .WORD ANIM_DLIST

; ── Sprite data ───────────────────────────────────────────────────────────────
    ORG $2400
    icl "graphics/sprite_data.asm"

; ── Run address ───────────────────────────────────────────────────────────────
    ORG $02E0
    .WORD ANIM_MAIN
