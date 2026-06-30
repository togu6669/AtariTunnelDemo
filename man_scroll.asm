
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
SCRN_LO    = $4010   ; rows   0-101  (102 x 40 = 4080 bytes, ends $4FFF)
SCRN_HI    = $5000   ; rows 102-191  ( 90 x 40 = 3600 bytes, ends $5E0F)
SCRN_SPLIT = 102     ; first row stored in SCRN_HI

; ── Sprite dimensions ─────────────────────────────────────────────────────────
SPR_W  = 24          ; bytes per row  (96 px / 4 px/byte)
SPR_H  = 120         ; rows

; Starting positions (byte-column, screen-row)
MAN_X0 = 16          ; right side: cols 16..39
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
END_ROW  .DS 1    ; loop termination row (= start + SPR_H)
SCR_COL  .DS 1    ; scratch: screen byte-column for col/row ops
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

        JSR INIT_ROW_TABLE

        ; Clear and pre-draw with DMA off (no flicker)
        JSR CLEAR_SCREEN

        ; Man at (16, 0)
        LDA #MAN_X0
        STA MAN_X
        STA SCR_COL
        LDA #MAN_Y0
        STA MAN_YL
        CLC
        ADC #SPR_H
        STA END_ROW
        LDA #<MAN_SPR
        STA SPRPTR
        LDA #>MAN_SPR 
        STA SPRPTR+1
        LDX #MAN_Y0
        JSR DRAW_SPR_FULL


loop    ldx #15         ; number of VBLANKs to wait
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
        inc SCRN_LO_DL
        clc
        inc SCRN_HI_DL
        rts

; ─── INIT_ROW_TABLE ───────────────────────────────────────────────────────────
; Builds ROW_TBL_LO and ROW_TBL_HI (192 entries each, stride 40)
INIT_ROW_TABLE:
    LDA #<SCRN_LO
    STA ROWPTR
    LDA #>SCRN_LO
    STA ROWPTR+1
    LDX #0
@irt_a:
    LDA ROWPTR
    STA ROW_TBL_LO,X
    LDA ROWPTR+1
    STA ROW_TBL_HI,X
    LDA ROWPTR
    CLC
    ADC #40
    STA ROWPTR
    BCC @irt_a_nc
    INC ROWPTR+1
@irt_a_nc:
    INX
    CPX #SCRN_SPLIT
    BCC @irt_a

    LDA #<SCRN_HI
    STA ROWPTR
    LDA #>SCRN_HI
    STA ROWPTR+1
@irt_b:
    LDA ROWPTR
    STA ROW_TBL_LO,X
    LDA ROWPTR+1
    STA ROW_TBL_HI,X
    LDA ROWPTR
    CLC
    ADC #40
    STA ROWPTR
    BCC @irt_b_nc
    INC ROWPTR+1
@irt_b_nc:
    INX
    CPX #192
    BCC @irt_b
    RTS

; ─── CLEAR_SCREEN ─────────────────────────────────────────────────────────────
; Zeros all 192 rows of screen RAM using the row table.
; Requires INIT_ROW_TABLE to have been called first.
CLEAR_SCREEN:
    LDX #0
@cs_row:
    LDA ROW_TBL_LO,X
    STA ROWPTR
    LDA ROW_TBL_HI,X
    STA ROWPTR+1
    LDA #$0F ; #0
    LDY #39
@cs_byte:
    STA (ROWPTR),Y
    DEY
    BPL @cs_byte
    INX
    CPX #192
    BCC @cs_row
    RTS

; ─── DRAW_SPR_FULL ────────────────────────────────────────────────────────────
; Draw full sprite: SPR_W bytes per row for SPR_H rows.
; Pre: SPRPTR = sprite data; SCR_COL = x byte-column; X = start screen row;
;      END_ROW = X + SPR_H
; Clobbers: A, X, Y, ROWPTR, SPRPTR
DRAW_SPR_FULL:
    LDA ROW_TBL_LO,X
    STA ROWPTR
    LDA ROW_TBL_HI,X
    STA ROWPTR+1
    LDA ROWPTR
    CLC
    ADC SCR_COL
    STA ROWPTR
    BCC @dsf1
    INC ROWPTR+1
@dsf1:
    LDY #(SPR_W-1)
@dsf2:
    LDA (SPRPTR),Y
    STA (ROWPTR),Y
    DEY
    BPL @dsf2
    ; advance sprite pointer by SPR_W
    LDA SPRPTR
    CLC
    ADC #SPR_W
    STA SPRPTR
    BCC @dsf3
    INC SPRPTR+1
@dsf3:
    INX
    CPX END_ROW
    BCC DRAW_SPR_FULL
    RTS

  ORG $2300
; Simple display list to be used as coarse scrolling comparison
ANIM_DLIST 
        .BYTE $70,$70,$70       ; 3x8=24 blank scan lines
        .BYTE $4E               ; mode E + LMS
SCRN_LO_DL
        .WORD MAN_SPR ;SCRN_LO           ; $4010
        .REPT 101
        .BYTE $0E               ; rows 1-101
        .ENDR
        .BYTE $4E               ; mode E + LMS
SCRN_HI_DL
        .WORD SCRN_HI           ; $5000  (ANTIC 4KB boundary)
        .REPT 89
        .BYTE $0E               ; rows 103-191
        .ENDR
        .BYTE $41               ; JVB
        .WORD ANIM_DLIST


; ─── Row address tables ───────────────────────────────────────────────────────
    ORG $2400
ROW_TBL_LO: .DS 192        ; lo byte of screen address for each row
    ORG $24C0
ROW_TBL_HI: .DS 192        ; hi byte

; ─── Sprite data ──────────────────────────────────────────────────────────────
    ORG $2580
        icl "graphics/sprite_data.asm"

; tell DOS where to run the program when loaded

; ─── Run address ──────────────────────────────────────────────────────────────
    ORG $02E0
    .WORD ANIM_MAIN
