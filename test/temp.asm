
ROW_LOOP
        LDY #0
COL_LOOP
        LDA (SRCPTR),Y
        CLC
        ADC PHASE
        AND #$0F
        TAX
        LDA SHADE_TABLE_HARD,X
        STA (DST0PTR),Y
        STA (DST1PTR),Y
        STA (DST2PTR),Y
        STA (DST3PTR),Y
        STA (DST4PTR),Y
        STA (DST5PTR),Y
        STA (DST6PTR),Y
        STA (DST7PTR),Y
        INY
        CPY #40
        BNE COL_LOOP

; test
; poziome paski
TEST_PATTERN
        .BYTE $00,$55,$AA,$FF

ROW_LOOP
        LDY #0

        LDA ROWCNT
        AND #$03
        TAX
        LDA TEST_PATTERN,X

COL_LOOP
        STA (DST0PTR),Y
        STA (DST1PTR),Y
        STA (DST2PTR),Y
        STA (DST3PTR),Y
        STA (DST4PTR),Y
        STA (DST5PTR),Y
        STA (DST6PTR),Y
        STA (DST7PTR),Y
        INY
        CPY #40
        BNE COL_LOOP

; kolumny pasy
ROW_LOOP
        LDY #0
COL_LOOP
        CPY #10
        BCC BAND0
        CPY #20
        BCC BAND1
        CPY #30
        BCC BAND2
        LDA #$FF
        JMP STORE

BAND0
        LDA #$00
        JMP STORE

BAND1
        LDA #$55
        JMP STORE

BAND2
        LDA #$AA

STORE
        STA (DST0PTR),Y
        STA (DST1PTR),Y
        STA (DST2PTR),Y
        STA (DST3PTR),Y
        STA (DST4PTR),Y
        STA (DST5PTR),Y
        STA (DST6PTR),Y
        STA (DST7PTR),Y
        INY
        CPY #40
        BNE COL_LOOP

; test pojedynczych linii
ROW_LOOP
        LDY #0
COL_LOOP
        LDA #$00
        STA (DST0PTR),Y

        LDA #$FF
        STA (DST1PTR),Y

        LDA #$55
        STA (DST2PTR),Y

        LDA #$AA
        STA (DST3PTR),Y

        LDA #$00
        STA (DST4PTR),Y

        LDA #$FF
        STA (DST5PTR),Y

        LDA #$55
        STA (DST6PTR),Y

        LDA #$AA
        STA (DST7PTR),Y

        INY
        CPY #40
        BNE COL_LOOP

