; symbol_anim.asm — standalone gender-symbol blend animation
; Man (male) enters from top-right, Woman (female) from bottom-left.
; Rings meet at screen centre.  GRAPHICS 7, 160x192, 2bpp, black bg, white symbols.
; Build: mads.exe symbol_anim.asm -o:build/symbol_anim.xex

; ── OS constants ──────────────────────────────────────────────────────────────
SDMCTL   = $022F
DLISTL   = $0230
DLISTH   = $0231
COLOR0   = $02C4
COLOR1   = $02C5
COLOR2   = $02C6
COLOR3   = $02C7
COLOR4   = $02C8
RTCLOK60 = $0019
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

; ── Zero-page variables at $B0 ────────────────────────────────────────────────
    ORG $B0
MAN_X    .DS 1    ; man X byte-column
MAN_YL   .DS 1    ; man Y row
; WOM_X    .DS 1    ; woman X byte-column
; WOM_YL   .DS 1    ; woman Y row
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

; ── Code ──────────────────────────────────────────────────────────────────────
    ORG $2000

; ─── ANIM_MAIN ────────────────────────────────────────────────────────────────
ANIM_MAIN:
    LDA #$00
    STA SDMCTL          ; DMA off during setup

    LDA #<ANIM_DLIST
    STA DLISTL
    LDA #>ANIM_DLIST
    STA DLISTH

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
    

    ; ; Woman at (0, 72)
    ; LDA #WOM_X0
    ; STA WOM_X
    ; STA SCR_COL
    ; LDA #WOM_Y0
    ; STA WOM_YL
    ; CLC
    ; ADC #SPR_H
    ; STA END_ROW
    ; LDA #<WOM_SPR
    ; STA SPRPTR
    ; LDA #>WOM_SPR
    ; STA SPRPTR+1
    ; LDX #WOM_Y0
    ; JSR DRAW_SPR_FULL

    ; Init counters
    LDA #0
    STA ACC_X
    STA ACC_Y
    STA FRAME

    LDA #$22
    STA SDMCTL          ; enable GFX7 DMA

; ─── ANIM_LOOP ────────────────────────────────────────────────────────────────
ANIM_LOOP:
    JSR WAIT_VBL

    ; X accumulator: step 8 times in 60 frames
    LDA ACC_X
    CLC
    ADC #8
    CMP #60
    BCC @ax_no
    SBC #60             ; carry was set by CMP, exact
    STA ACC_X
    LDA #1
    BNE @ax_done        ; always
@ax_no:
    STA ACC_X
    LDA #0
@ax_done:
    STA STEP_X

    ; Y accumulator: step 36 times in 60 frames
    LDA ACC_Y
    CLC
    ADC #36
    CMP #60
    BCC @ay_no
    SBC #60
    STA ACC_Y
    LDA #1
    BNE @ay_done
@ay_no:
    STA ACC_Y
    LDA #0
@ay_done:
    STA STEP_Y

    ; ── Phase 1: clear old trailing strips (using OLD positions) ────────────
    LDA STEP_X
    BEQ @skip_xclear

    ; Clear old right column of man: col = MAN_X+23
    LDA MAN_X
    CLC
    ADC #(SPR_W-1)
    STA SCR_COL
    LDA MAN_YL
    CLC
    ADC #SPR_H
    STA END_ROW
    LDX MAN_YL
    JSR CLEAR_COL

    ; Clear old left column of woman: col = WOM_X
    ; LDA WOM_X
    ; STA SCR_COL
    ; LDA WOM_YL
    ; CLC
    ; ADC #SPR_H
    ; STA END_ROW
    ; LDX WOM_YL
    ; JSR CLEAR_COL

@skip_xclear:
    LDA STEP_Y
    BEQ @skip_yclear

    ; Clear old top row of man
    LDA MAN_X
    STA SCR_COL
    LDX MAN_YL
    JSR CLEAR_ROW

    ; Clear old bottom row of woman: row = WOM_YL+SPR_H-1
    ; LDA WOM_YL
    ; CLC
    ; ADC #(SPR_H-1)
    ; TAX
    ; LDA WOM_X
    ; STA SCR_COL
    ; JSR CLEAR_ROW

@skip_yclear:

    ; ── Phase 2: update positions ────────────────────────────────────────────
    LDA STEP_X
    BEQ @skip_xupd
    DEC MAN_X
    ; INC WOM_X
@skip_xupd:

    LDA STEP_Y
    BEQ @skip_yupd
    INC MAN_YL
    ; DEC WOM_YL
@skip_yupd:

    ; ── Phase 3: draw new leading strips (using NEW positions) ──────────────
    LDA STEP_X
    BEQ @skip_xdraw

    ; Draw new left column of man: col=MAN_X, sprite col 0
    LDA MAN_X
    STA SCR_COL
    LDA #<MAN_SPR
    STA SPRPTR
    LDA #>MAN_SPR
    STA SPRPTR+1
    LDA MAN_YL
    CLC
    ADC #SPR_H
    STA END_ROW
    LDX MAN_YL
    JSR DRAW_COL

    ; Draw new right column of woman: col=WOM_X+23, sprite col 23
    ; LDA WOM_X
    ; CLC
    ; ADC #(SPR_W-1)
    ; STA SCR_COL
    ; LDA #<(WOM_SPR+SPR_W-1)
    ; STA SPRPTR
    ; LDA #>(WOM_SPR+SPR_W-1)
    ; STA SPRPTR+1
    ; LDA WOM_YL
    ; CLC
    ; ADC #SPR_H
    ; STA END_ROW
    ; LDX WOM_YL
    ; JSR DRAW_COL

@skip_xdraw:
    LDA STEP_Y
    BEQ @skip_ydraw

    ; Draw new bottom row of man: row=MAN_YL+119, sprite row 119
    LDA MAN_YL
    CLC
    ADC #(SPR_H-1)
    TAX
    LDA MAN_X
    STA SCR_COL
    LDA #<(MAN_SPR+(SPR_H-1)*SPR_W)
    STA SPRPTR
    LDA #>(MAN_SPR+(SPR_H-1)*SPR_W)
    STA SPRPTR+1
    JSR DRAW_ROW

    ; Draw new top row of woman: row=WOM_YL, sprite row 0
    ; LDX WOM_YL
    ; LDA WOM_X
    ; STA SCR_COL
    ; LDA #<WOM_SPR
    ; STA SPRPTR
    ; LDA #>WOM_SPR
    ; STA SPRPTR+1
    ; JSR DRAW_ROW

@skip_ydraw:

    INC FRAME
    LDA FRAME
    CMP #ANIM_FRAMES
    BCS @loop_exit      ; frame >= ANIM_FRAMES: done
    JMP ANIM_LOOP
@loop_exit:

; ─── HOLD ─────────────────────────────────────────────────────────────────────
    LDA #0
    STA HOLD_CTR
HOLD_LOOP:
    JSR WAIT_VBL
    INC HOLD_CTR
    LDA HOLD_CTR
    CMP #HOLD_FRAMES
    BCC HOLD_LOOP
    JMP (DOSVEC)

; ─── WAIT_VBL ─────────────────────────────────────────────────────────────────
WAIT_VBL:
    LDA RTCLOK60
@wv CMP RTCLOK60
    BEQ @wv
    RTS

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
    LDA #0
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

; ─── CLEAR_COL ────────────────────────────────────────────────────────────────
; Zero one byte per screen row for SPR_H rows.
; Pre: SCR_COL = screen byte-column; X = start row; END_ROW = X + SPR_H
; Clobbers: A, X, Y, ROWPTR
CLEAR_COL:
    LDA ROW_TBL_LO,X
    STA ROWPTR
    LDA ROW_TBL_HI,X
    STA ROWPTR+1
    LDA ROWPTR
    CLC
    ADC SCR_COL
    STA ROWPTR
    BCC @cc1
    INC ROWPTR+1
@cc1:
    LDA #0
    LDY #0
    STA (ROWPTR),Y
    INX
    CPX END_ROW
    BCC CLEAR_COL
    RTS

; ─── DRAW_COL ─────────────────────────────────────────────────────────────────
; Copy one byte per row (stride SPR_W) from SPRPTR for SPR_H rows.
; Pre: SCR_COL = screen byte-column; X = start row; END_ROW = X + SPR_H
;      SPRPTR = &sprite[0][col_offset]  (advances by SPR_W each iteration)
; Clobbers: A, X, Y, ROWPTR, SPRPTR
DRAW_COL:
    LDA ROW_TBL_LO,X
    STA ROWPTR
    LDA ROW_TBL_HI,X
    STA ROWPTR+1
    LDA ROWPTR
    CLC
    ADC SCR_COL
    STA ROWPTR
    BCC @dc1
    INC ROWPTR+1
@dc1:
    LDY #0
    LDA (SPRPTR),Y
    STA (ROWPTR),Y
    LDA SPRPTR
    CLC
    ADC #SPR_W
    STA SPRPTR
    BCC @dc2
    INC SPRPTR+1
@dc2:
    INX
    CPX END_ROW
    BCC DRAW_COL
    RTS

; ─── CLEAR_ROW ────────────────────────────────────────────────────────────────
; Zero SPR_W bytes at one screen row starting at SCR_COL.
; Pre: X = screen row; SCR_COL = start byte-column
; Clobbers: A, Y, ROWPTR
CLEAR_ROW:
    LDA ROW_TBL_LO,X
    STA ROWPTR
    LDA ROW_TBL_HI,X
    STA ROWPTR+1
    LDA ROWPTR
    CLC
    ADC SCR_COL
    STA ROWPTR
    BCC @cr1
    INC ROWPTR+1
@cr1:
    LDA #0
    LDY #(SPR_W-1)
@cr2:
    STA (ROWPTR),Y
    DEY
    BPL @cr2
    RTS

; ─── DRAW_ROW ─────────────────────────────────────────────────────────────────
; Copy SPR_W bytes from SPRPTR to screen row X starting at SCR_COL.
; Pre: X = screen row; SCR_COL = start byte-column; SPRPTR = source
; Clobbers: A, Y, ROWPTR
DRAW_ROW:
    LDA ROW_TBL_LO,X
    STA ROWPTR
    LDA ROW_TBL_HI,X
    STA ROWPTR+1
    LDA ROWPTR
    CLC
    ADC SCR_COL
    STA ROWPTR
    BCC @dr1
    INC ROWPTR+1
@dr1:
    LDY #(SPR_W-1)
@dr2:
    LDA (SPRPTR),Y
    STA (ROWPTR),Y
    DEY
    BPL @dr2
    RTS

; ─── Display list ─────────────────────────────────────────────────────────────
    ORG $2300

ANIM_DLIST:
    .BYTE $70,$70,$70       ; 3x8=24 blank scan lines
    .BYTE $4E               ; mode E + LMS
    .WORD SCRN_LO           ; $4010
    .REPT 101
      .BYTE $0E             ; rows 1-101
    .ENDR
    .BYTE $4E               ; mode E + LMS
    .WORD SCRN_HI           ; $5000  (ANTIC 4KB boundary)
    .REPT 89
      .BYTE $0E             ; rows 103-191
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

; ─── Run address ──────────────────────────────────────────────────────────────
    ORG $02E0
    .WORD ANIM_MAIN
