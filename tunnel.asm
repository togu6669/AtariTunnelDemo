        ORG $2000

SCREEN   = $4010
SAVMSC   = $0058
SDLSTL   = $0230
SDMCTL   = $022F
COLOR0   = $02C4
COLOR1   = $02C5
COLOR2   = $02C6
COLOR3   = $02C7
COLOR4   = $02C8
RTCLOK60 = $0014
DMACTL   = $D400
DLISTL   = $D402

SRCPTR   = $80
DST0PTR  = $82
DST1PTR  = $84
DST2PTR  = $86
DST3PTR  = $88
DST4PTR  = $8A
DST5PTR  = $8C
DST6PTR  = $8E
DST7PTR  = $90

; -------------------------
; Zmienne
; -------------------------
PHASE   .BYTE 0
ROWCNT  .BYTE 0

; -------------------------
; Start
; -------------------------
START
        JSR INIT_SCREEN
MAIN
        JSR DRAW
        JSR WAIT_VBL
        INC PHASE
        JMP MAIN

; -------------------------
; Inicjalizacja ekranu
; -------------------------
INIT_SCREEN
        LDA #<SCREEN
        STA SAVMSC
        LDA #>SCREEN
        STA SAVMSC+1

        LDA #<DISPLAY_LIST
        STA SDLSTL
        STA DLISTL
        LDA #>DISPLAY_LIST
        STA SDLSTL+1
        STA DLISTL+1

        LDA #$22
        STA SDMCTL
        STA DMACTL

        LDA #$04
        STA COLOR0
        LDA #$08
        STA COLOR1
        LDA #$0C
        STA COLOR2
        LDA #$B8
        STA COLOR3
        LDA #$00
        STA COLOR4

        RTS

; -------------------------
; Czekaj na kolejna ramke
; -------------------------
WAIT_VBL
        LDA RTCLOK60
WAIT_LOOP
        CMP RTCLOK60
        BEQ WAIT_LOOP
        RTS

; -------------------------
; Rysowanie bitmapy 160x192 z mapy 40x24
; -------------------------
DRAW
        LDA #<DIST_TABLE
        STA SRCPTR
        LDA #>DIST_TABLE
        STA SRCPTR+1

        LDA #<$4010
        STA DST0PTR
        LDA #>$4010
        STA DST0PTR+1
        LDA #<$4038
        STA DST1PTR
        LDA #>$4038
        STA DST1PTR+1
        LDA #<$4060
        STA DST2PTR
        LDA #>$4060
        STA DST2PTR+1
        LDA #<$4088
        STA DST3PTR
        LDA #>$4088
        STA DST3PTR+1
        LDA #<$40B0
        STA DST4PTR
        LDA #>$40B0
        STA DST4PTR+1
        LDA #<$40D8
        STA DST5PTR
        LDA #>$40D8
        STA DST5PTR+1
        LDA #<$4100
        STA DST6PTR
        LDA #>$4100
        STA DST6PTR+1
        LDA #<$4128
        STA DST7PTR
        LDA #>$4128
        STA DST7PTR+1

        LDA #24
        STA ROWCNT

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

;tutaj wstawic wyciety kod
        CLC
        LDA SRCPTR
        ADC #40
        STA SRCPTR
        LDA SRCPTR+1
        ADC #0
        STA SRCPTR+1

        JSR ADVANCE_DST

        DEC ROWCNT
        LDA ROWCNT
        BNE ROW_LOOP

        RTS

ADVANCE_DST
        CLC
        LDA DST0PTR
        ADC #$40
        STA DST0PTR
        LDA DST0PTR+1
        ADC #$01
        STA DST0PTR+1

        CLC
        LDA DST1PTR
        ADC #$40
        STA DST1PTR
        LDA DST1PTR+1
        ADC #$01
        STA DST1PTR+1

        CLC
        LDA DST2PTR
        ADC #$40
        STA DST2PTR
        LDA DST2PTR+1
        ADC #$01
        STA DST2PTR+1

        CLC
        LDA DST3PTR
        ADC #$40
        STA DST3PTR
        LDA DST3PTR+1
        ADC #$01
        STA DST3PTR+1

        CLC
        LDA DST4PTR
        ADC #$40
        STA DST4PTR
        LDA DST4PTR+1
        ADC #$01
        STA DST4PTR+1

        CLC
        LDA DST5PTR
        ADC #$40
        STA DST5PTR
        LDA DST5PTR+1
        ADC #$01
        STA DST5PTR+1

        CLC
        LDA DST6PTR
        ADC #$40
        STA DST6PTR
        LDA DST6PTR+1
        ADC #$01
        STA DST6PTR+1

        CLC
        LDA DST7PTR
        ADC #$40
        STA DST7PTR
        LDA DST7PTR+1
        ADC #$01
        STA DST7PTR+1

        RTS

; -------------------------
; Display list: tryb bitmapowy 160x192, 4 kolory
; -------------------------

DISPLAY_LIST
        .BYTE $4E, a($4010)   ; pierwsza linia z LMS
        :101 .BYTE $0E        ; kolejne linie 1..102

        .BYTE $4E, a($5000)   ; nowy LMS od linii 102
        :89 .BYTE $0E         ; kolejne linie 104..191

        .BYTE $41, a(DISPLAY_LIST)
; -------------------------
; Tablica cieniowania
; -------------------------
; Preset 1: twarde progi, dobry do testu adresowania
SHADE_TABLE_HARD
        .BYTE $00,$00,$00,$00,$55,$55,$55,$55
        .BYTE $AA,$AA,$AA,$AA,$FF,$FF,$FF,$FF

; Preset 2: lagodne przejscie, dobry do sprawdzania geometrii
SHADE_TABLE_SOFT
        .BYTE $00,$00,$55,$55,$55,$AA,$AA,$AA
        .BYTE $AA,$FF,$FF,$AA,$AA,$55,$55,$00

; Preset 3: naprzemienne wzorce, dobry do testu aliasingu bitow
SHADE_TABLE_ALIAS
        .BYTE $00,$00,$55,$55,$AA,$AA,$FF,$FF
        .BYTE $FF,$FF,$AA,$AA,$55,$55,$00,$00

; Aktywny preset: podmien etykiete w nastepnej linii na
; SHADE_TABLE_HARD / SHADE_TABLE_SOFT / SHADE_TABLE_ALIAS
SHADE_TABLE
        .BYTE $00,$00,$00,$00,$55,$55,$55,$55
        .BYTE $AA,$AA,$AA,$AA,$FF,$FF,$FF,$FF

; -------------------------
; Tablica dystansu
; -------------------------
DIST_TABLE
        .BYTE 7,6,5,4,4,3,2,1,0,0,15,15,14,13,13,13,12,12,12,12,12,12,12,12,12,13,13,13,14,15,15,0,0,1,2,3,4,4,5,6
        .BYTE 6,5,5,4,3,2,1,1,0,15,14,14,13,13,12,12,11,11,11,11,11,11,11,11,11,12,12,13,13,14,14,15,0,1,1,2,3,4,5,5
        .BYTE 6,5,4,3,2,2,1,0,15,14,14,13,12,12,11,11,10,10,10,10,10,10,10,10,10,11,11,12,12,13,14,14,15,0,1,2,2,3,4,5
        .BYTE 5,5,4,3,2,1,0,15,15,14,13,12,12,11,10,10,9,9,9,9,9,9,9,9,9,10,10,11,12,12,13,14,15,15,0,1,2,3,4,5
        .BYTE 5,4,3,2,1,1,0,15,14,13,12,12,11,10,10,9,8,8,8,8,8,8,8,8,8,9,10,10,11,12,12,13,14,15,0,1,1,2,3,4
        .BYTE 5,4,3,2,1,0,15,14,13,13,12,11,10,9,9,8,8,7,7,7,7,7,7,7,8,8,9,9,10,11,12,13,13,14,15,0,1,2,3,4
        .BYTE 4,3,2,2,1,0,15,14,13,12,11,10,10,9,8,7,7,6,6,6,6,6,6,6,7,7,8,9,10,10,11,12,13,14,15,0,1,2,2,3
        .BYTE 4,3,2,1,0,15,14,13,13,12,11,10,9,8,7,7,6,5,5,5,5,5,5,5,6,7,7,8,9,10,11,12,13,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,12,11,10,9,8,8,7,6,5,5,4,4,4,4,4,5,5,6,7,8,8,9,10,11,12,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,12,11,10,9,8,7,6,5,5,4,3,3,3,3,3,4,5,5,6,7,8,9,10,11,12,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,12,11,10,9,8,7,6,5,4,3,2,2,2,2,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,1,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,1,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,12,11,10,9,8,7,6,5,4,3,2,2,2,2,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,12,11,10,9,8,7,6,5,5,4,3,3,3,3,3,4,5,5,6,7,8,9,10,11,12,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,12,11,10,9,8,8,7,6,5,5,4,4,4,4,4,5,5,6,7,8,8,9,10,11,12,13,14,15,0,1,2,3
        .BYTE 4,3,2,1,0,15,14,13,13,12,11,10,9,8,7,7,6,5,5,5,5,5,5,5,6,7,7,8,9,10,11,12,13,13,14,15,0,1,2,3
        .BYTE 4,3,2,2,1,0,15,14,13,12,11,10,10,9,8,7,7,6,6,6,6,6,6,6,7,7,8,9,10,10,11,12,13,14,15,0,1,2,2,3
        .BYTE 5,4,3,2,1,0,15,14,13,13,12,11,10,9,9,8,8,7,7,7,7,7,7,7,8,8,9,9,10,11,12,13,13,14,15,0,1,2,3,4
        .BYTE 5,4,3,2,1,1,0,15,14,13,12,12,11,10,10,9,8,8,8,8,8,8,8,8,8,9,10,10,11,12,12,13,14,15,0,1,1,2,3,4
        .BYTE 5,5,4,3,2,1,0,15,15,14,13,12,12,11,10,10,9,9,9,9,9,9,9,9,9,10,10,11,12,12,13,14,15,15,0,1,2,3,4,5
        .BYTE 6,5,4,3,2,2,1,0,15,14,14,13,12,12,11,11,10,10,10,10,10,10,10,10,10,11,11,12,12,13,14,14,15,0,1,2,2,3,4,5
        .BYTE 6,5,5,4,3,2,1,1,0,15,14,14,13,13,12,12,11,11,11,11,11,11,11,11,11,12,12,13,13,14,14,15,0,1,1,2,3,4,5,5

; adres startowy programu
        ORG $02E0
        .WORD START
