
; ── OS constants ──────────────────────────────────────────────────────────────
SDMCTL   = $022F
DLISTL   = $0230
DLISTH   = $0231
COLOR0   = $02C4
COLOR1   = $02C5
COLOR2   = $02C6
COLOR3   = $02C7
COLOR4   = $02C8
RTCLOK60 = $0014     ; 3rd byte of RTCLOCK (increments at 60Hz)
DOSVEC   = $000A

; ── Screen RAM ────────────────────────────────────────────────────────────────
; SCRN_LO    = $4010   ; rows   0-101  (102 x 40 = 4080 bytes, ends $4FFF)
; SCRN_HI    = $5000   ; rows 102-191  ( 90 x 40 = 3600 bytes, ends $5E0F)
; SCRN_SPLIT = 102     ; first row stored in SCRN_HI

SCRN_LO    = $4FFF   ; reversed rows for scrolling down  0-101  (102 x 40 = 4080 bytes, beginning $4010)
SCRN_HI    = $5E0F   ; reversed rows 102-191  ( 90 x 40 = 3600 bytes, ends $5000)
SCRN_SPLIT = 102     ; first row stored in SCRN_HI

; ── Sprite dimensions ─────────────────────────────────────────────────────────
SPR_W  = 24          ; bytes per row  (96 px / 4 px/byte)
SPR_H  = 120         ; rows

; Starting positions (byte-column, screen-row)
MAN_X0 = 8          ; right side: cols 8..31
MAN_Y0 = 0           ; top of screen
; WOM_X0 = 0           ; left side: cols 0..23
; WOM_Y0 = 72          ; bottom: rows 72..191

; Final positions (rings overlap at screen centre)
FINAL_X = 8
FINAL_Y = 36

ANIM_FRAMES = 60
HOLD_FRAMES = 120

   ORG $B0
MAN_X    .DS 1    ; man X byte-column
MAN_YL   .DS 1    ; man Y row
ACC_X    .DS 1    ; X sub-step accumulator (0..59)
ACC_Y    .DS 1    ; Y sub-step accumulator (0..59)
FRAME    .DS 1    ; animation frame counter
HOLD_CTR .DS 1    ; hold-phase counter
ROWPTR   .DS 2    ; scratch: current screen row address
SPRPTR   .DS 2    ; scratch: sprite data pointer
STEP_X   .DS 1    ; flag: 1 if X stepped this frame
STEP_Y   .DS 1    ; flag: 1 if Y stepped this frame
    
    ORG $2000

ANIM_MAIN
        LDA #$00
        STA SDMCTL          ; DMA off during setup

        lda #<ANIM_DLIST
        sta DLISTL
        lda #>ANIM_DLIST
        sta DLISTH

        LDA #$00
        STA COLOR0
        STA COLOR1
        STA COLOR3
        STA COLOR4
        LDA #$0F            ; white
        STA COLOR2

        ; Clear and pre-draw with DMA off (no flicker)
        JSR CLEAR_SCREEN

        ; Man at (MAN_X0, MAN_Y0): pre-compute ROWPTR = SCRN_LO + MAN_Y0*40 + MAN_X0
        ; MAN_Y0 = 0, so ROWPTR = SCRN_LO + MAN_X0
        LDA #MAN_X0
        STA MAN_X
        LDA #MAN_Y0
        STA MAN_YL
        LDA #<(SCRN_LO + MAN_X0)
        STA ROWPTR
        LDA #>(SCRN_LO + MAN_X0)
        STA ROWPTR+1
        LDA #<MAN_SPR
        STA SPRPTR
        LDA #>MAN_SPR
        STA SPRPTR+1
        JSR DRAW_SPR_FULL

        ; Draw the man 
        LDA #$22
        STA SDMCTL


loop    ldx #2          ; number of VBLANKs to wait

_start  lda RTCLOK60    ; check fastest moving RTCLOCK byte
_wait   cmp RTCLOK60    ; VBLANK will update this
        beq _wait       ; delay until VBLANK changes it
        dex             ; delay for a number of VBLANKs
        bpl _start

        ; enough time has passed, scroll one line
        jsr coarse_scroll_down

        jmp loop

; move viewport one line down by pointing display list start address

coarse_scroll_down
        clc
        lda SCRN_LO_DL   ; move display list start address down by 40 bytes (1 row)
        sbc #40
        sta SCRN_LO_DL
        lda SCRN_LO_DL+1
        sbc #0
        sta SCRN_LO_DL+1

        lda SCRN_HI_DL  ; move display list secondary address down by 40 bytes (1 row)
        sbc #40
        sta SCRN_HI_DL
        lda SCRN_HI_DL+1
        sbc #0
        sta SCRN_HI_DL+1
        rts


; ─── CLEAR_SCREEN ─────────────────────────────────────────────────────────────
; Zeros 384 rows (double-height virtual screen) × 40 bytes = 15360 bytes
; starting at SCRN_LO.  Uses a direct pointer; does not need the row table.
; 16-bit row counter: ACC_X (hi) : X (lo).  Terminates at ACC_X:X = $01:$80.
CLEAR_SCREEN:
    LDA #<SCRN_LO
    STA ROWPTR
    LDA #>SCRN_LO
    STA ROWPTR+1
    LDA #0
    STA ACC_X           ; hi byte of row counter
    LDX #0              ; lo byte of row counter
@cs_row:
    LDA #0
    LDY #39
@cs_byte:
    STA (ROWPTR),Y
    DEY
    BPL @cs_byte
    LDA ROWPTR
    CLC
    ADC #40
    STA ROWPTR
    BCC @cs_nc
    INC ROWPTR+1
@cs_nc:
    INX
    BNE @cs_chk
    INC ACC_X
@cs_chk:
    CPX #<384           ; $80 — lo byte of 384 ($0180)
    BNE @cs_row
    LDA ACC_X
    CMP #>384           ; $01 — hi byte of 384
    BNE @cs_row
    RTS

; ─── DRAW_SPR_FULL ────────────────────────────────────────────────────────────
; Draw full sprite: SPR_W bytes per row for SPR_H rows.
; Pre: ROWPTR = destination address of first sprite row (column offset included)
;      SPRPTR = sprite data
; Clobbers: A, X, Y, ROWPTR, SPRPTR
DRAW_SPR_FULL:
    LDX #SPR_H
@dsf_row:
    LDY #(SPR_W-1)
@dsf_byte:
    LDA (SPRPTR),Y
    STA (ROWPTR),Y
    DEY
    BPL @dsf_byte
    LDA SPRPTR
    CLC
    ADC #SPR_W
    STA SPRPTR
    BCC @dsf_s1
    INC SPRPTR+1
@dsf_s1:
    LDA ROWPTR
    CLC
    ADC #40
    STA ROWPTR
    BCC @dsf_s2
    INC ROWPTR+1
@dsf_s2:
    DEX
    BNE @dsf_row
    RTS

  ORG $2300
; Simple display list to be used as coarse scrolling comparison
ANIM_DLIST 
        .BYTE $70,$70,$70       ; 3x8=24 blank scan lines
        .BYTE $4E               ; mode E + LMS
SCRN_LO_DL
        .WORD SCRN_LO           ; $4010 or $4FFF (ANTIC 4KB boundary)
        .REPT 101
        .BYTE $0E               ; rows 1-101
        .ENDR
        .BYTE $4E               ; mode E + LMS
SCRN_HI_DL
        .WORD SCRN_HI           ; $5000 or $5E0F (ANTIC 4KB boundary)
        .REPT 89
        .BYTE $0E               ; rows 103-191
        .ENDR
        .BYTE $41               ; JVB
        .WORD ANIM_DLIST


; ─── Sprite data ──────────────────────────────────────────────────────────────
    ORG $2400
        icl "graphics/sprite_data.asm"

; tell DOS where to run the program when loaded

; ─── Run address ──────────────────────────────────────────────────────────────
    ORG $02E0
    .WORD ANIM_MAIN
