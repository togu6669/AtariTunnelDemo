; Pure-ASM POKEY music module for Atari 8-bit
;
; Usage:
;   1. Add: ICL "music.asm"
;   2. Call JSR MUSIC_INIT once at startup
;   3. Call JSR MUSIC_PLAY_FRAME once per frame
;
; Entry points:
;   MUSIC_INIT
;   MUSIC_PLAY_FRAME
;   MUSIC_STOP

MUSIC_AUDF1  = $D200
MUSIC_AUDC1  = $D201
MUSIC_AUDF2  = $D202
MUSIC_AUDC2  = $D203
MUSIC_AUDF3  = $D204
MUSIC_AUDC3  = $D205
MUSIC_AUDF4  = $D206
MUSIC_AUDC4  = $D207
MUSIC_AUDCTL = $D208
MUSIC_SKCTL  = $D20F

MUSIC_LEN      = 32
MUSIC_NOTE_MAX = 30

MUSIC_STEP         .BYTE 0
MUSIC_TICKS        .BYTE 0
MUSIC_ARP_PHASE    .BYTE 0
MUSIC_ARP_WAIT     .BYTE 0
MUSIC_HARMONY_ROOT .BYTE 0
MUSIC_SNARE_TMR    .BYTE 0
MUSIC_KICK_TMR     .BYTE 0

MUSIC_INIT
        LDA #$00
        STA MUSIC_AUDCTL

        LDA #$03
        STA MUSIC_SKCTL

        LDA #$00
        STA MUSIC_AUDC1
        STA MUSIC_AUDC2
        STA MUSIC_AUDC3
        STA MUSIC_AUDC4
        STA MUSIC_STEP
        STA MUSIC_TICKS
        STA MUSIC_ARP_PHASE
        STA MUSIC_ARP_WAIT
        STA MUSIC_HARMONY_ROOT
        STA MUSIC_SNARE_TMR
        STA MUSIC_KICK_TMR
        RTS

MUSIC_STOP
        LDA #$00
        STA MUSIC_AUDC1
        STA MUSIC_AUDC2
        STA MUSIC_AUDC3
        STA MUSIC_AUDC4
        STA MUSIC_ARP_WAIT
        RTS

MUSIC_PLAY_FRAME
        JSR MUSIC_UPDATE_DRUMS
        JSR MUSIC_UPDATE_ARP

        LDA MUSIC_TICKS
        BEQ MUSIC_LOAD_STEP

        DEC MUSIC_TICKS
        RTS

MUSIC_LOAD_STEP
        LDX MUSIC_STEP

        LDA MUSIC_DUR,X
        STA MUSIC_TICKS
        DEC MUSIC_TICKS

        LDA MUSIC_LEAD_PATTERN,X
        JSR MUSIC_SET_CH1_FROM_NOTE

        LDA MUSIC_HARMONY_PATTERN,X
        STA MUSIC_HARMONY_ROOT
        LDA #$00
        STA MUSIC_ARP_PHASE
        STA MUSIC_ARP_WAIT
        JSR MUSIC_UPDATE_ARP

        LDA MUSIC_KICK_PATTERN,X
        BEQ MUSIC_CHECK_SNARE
        JSR MUSIC_TRIGGER_KICK

MUSIC_CHECK_SNARE
        LDA MUSIC_SNARE_PATTERN,X
        BEQ MUSIC_ADVANCE_STEP
        JSR MUSIC_TRIGGER_SNARE

MUSIC_ADVANCE_STEP
        INX
        CPX #MUSIC_LEN
        BCC MUSIC_STORE_STEP
        LDX #0

MUSIC_STORE_STEP
        STX MUSIC_STEP
        RTS

MUSIC_SET_CH1_FROM_NOTE
        BEQ MUSIC_CH1_REST
        TAY
        LDA MUSIC_NOTE_TABLE,Y
        STA MUSIC_AUDF1
        LDA #$A6
        STA MUSIC_AUDC1
        RTS

MUSIC_CH1_REST
        LDA #$00
        STA MUSIC_AUDC1
        RTS

MUSIC_SET_CH2_FROM_NOTE
        BEQ MUSIC_CH2_REST
        TAY
        LDA MUSIC_NOTE_TABLE,Y
        STA MUSIC_AUDF2
        LDA #$A4
        STA MUSIC_AUDC2
        RTS

MUSIC_CH2_REST
        LDA #$00
        STA MUSIC_AUDC2
        RTS

MUSIC_UPDATE_ARP
        LDA MUSIC_HARMONY_ROOT
        BEQ MUSIC_CH2_REST

        LDA MUSIC_ARP_WAIT
        BEQ MUSIC_ARP_PLAY
        DEC MUSIC_ARP_WAIT
        RTS

MUSIC_ARP_PLAY

        LDX MUSIC_ARP_PHASE
        LDA MUSIC_ARP_OFFSETS,X
        CLC
        ADC MUSIC_HARMONY_ROOT
        CMP #MUSIC_NOTE_MAX+1
        BCC MUSIC_ARP_NOTE_OK
        LDA #MUSIC_NOTE_MAX

MUSIC_ARP_NOTE_OK
        JSR MUSIC_SET_CH2_FROM_NOTE

        LDA #1
        STA MUSIC_ARP_WAIT

        LDA MUSIC_ARP_PHASE
        CLC
        ADC #1
        AND #$03
        STA MUSIC_ARP_PHASE
        RTS

MUSIC_TRIGGER_KICK
        LDA #5
        STA MUSIC_KICK_TMR
        LDA #$12
        STA MUSIC_AUDF4
        LDA #$AE
        STA MUSIC_AUDC4
        RTS

MUSIC_TRIGGER_SNARE
        LDA #4
        STA MUSIC_SNARE_TMR
        LDA #$10
        STA MUSIC_AUDF3
        LDA #$8C
        STA MUSIC_AUDC3
        RTS

MUSIC_UPDATE_DRUMS
        JSR MUSIC_UPDATE_KICK
        JSR MUSIC_UPDATE_SNARE
        RTS

MUSIC_UPDATE_KICK
        LDA MUSIC_KICK_TMR
        BEQ MUSIC_NO_KICK

        CMP #5
        BNE MUSIC_KICK_STAGE2
        LDA #$18
        STA MUSIC_AUDF4
        LDA #$AC
        STA MUSIC_AUDC4
        DEC MUSIC_KICK_TMR
        RTS

MUSIC_KICK_STAGE2
        CMP #4
        BNE MUSIC_KICK_STAGE3
        LDA #$20
        STA MUSIC_AUDF4
        LDA #$A8
        STA MUSIC_AUDC4
        DEC MUSIC_KICK_TMR
        RTS

MUSIC_KICK_STAGE3
        CMP #3
        BNE MUSIC_KICK_STAGE4
        LDA #$34
        STA MUSIC_AUDF4
        LDA #$A6
        STA MUSIC_AUDC4
        DEC MUSIC_KICK_TMR
        RTS

MUSIC_KICK_STAGE4
        CMP #2
        BNE MUSIC_KICK_STAGE5
        LDA #$54
        STA MUSIC_AUDF4
        LDA #$A4
        STA MUSIC_AUDC4
        DEC MUSIC_KICK_TMR
        RTS

MUSIC_KICK_STAGE5
        LDA #$00
        STA MUSIC_AUDC4
        STA MUSIC_KICK_TMR

MUSIC_NO_KICK
        RTS

MUSIC_UPDATE_SNARE
        LDA MUSIC_SNARE_TMR
        BEQ MUSIC_NO_SNARE

        CMP #4
        BNE MUSIC_SNARE_STAGE2
        LDA #$14
        STA MUSIC_AUDF3
        LDA #$8A
        STA MUSIC_AUDC3
        DEC MUSIC_SNARE_TMR
        RTS

MUSIC_SNARE_STAGE2
        CMP #3
        BNE MUSIC_SNARE_STAGE3
        LDA #$18
        STA MUSIC_AUDF3
        LDA #$88
        STA MUSIC_AUDC3
        DEC MUSIC_SNARE_TMR
        RTS

MUSIC_SNARE_STAGE3
        CMP #2
        BNE MUSIC_SNARE_STAGE4
        LDA #$24
        STA MUSIC_AUDF3
        LDA #$86
        STA MUSIC_AUDC3
        DEC MUSIC_SNARE_TMR
        RTS

MUSIC_SNARE_STAGE4
        LDA #$00
        STA MUSIC_AUDC3
        STA MUSIC_SNARE_TMR

MUSIC_NO_SNARE
        RTS

; 0 = rest, 1..30 = note index
MUSIC_NOTE_TABLE
        .BYTE 0
        .BYTE 228,215,203,191,181,171,161,152
        .BYTE 143,135,127,120,114,107,101,96
        .BYTE 90,85,80,76,72,68,64,60
        .BYTE 57,53,50,47,45,42

; Darker, harsher machine-pulse cycle for channel 2
MUSIC_ARP_OFFSETS
        .BYTE 0,1,6,10

; Main lead line: low, repetitive, more like a machine stab than a melody.
MUSIC_LEAD_PATTERN
        .BYTE 8,0,0,0,8,0,10,0
        .BYTE 8,0,0,0,8,0,12,0
        .BYTE 7,0,0,0,7,0,10,0
        .BYTE 7,0,8,0,7,0,5,0

; Lower harmony roots for a darker bed.
MUSIC_HARMONY_PATTERN
        .BYTE 3,3,3,3,7,7,7,7
        .BYTE 2,2,2,2,8,8,8,8
        .BYTE 3,3,3,3,7,7,7,7
        .BYTE 5,5,5,5,2,2,2,2

; 32-step percussion grid: heavier and more industrial.
MUSIC_KICK_PATTERN
        .BYTE 1,0,0,0,1,0,0,0
        .BYTE 1,0,1,0,1,0,0,0
        .BYTE 1,0,0,0,1,0,1,0
        .BYTE 1,0,0,1,1,0,0,0

MUSIC_SNARE_PATTERN
        .BYTE 0,0,0,0,0,0,0,0
        .BYTE 1,0,0,0,0,0,0,0
        .BYTE 0,0,0,0,0,0,0,0
        .BYTE 1,0,0,0,1,0,0,0

; Slower step than the demo-scene version, for a darker industrial pulse.
MUSIC_DUR
        .BYTE 4,4,4,4,4,4,4,4
        .BYTE 4,4,4,4,4,4,4,4
        .BYTE 4,4,4,4,4,4,4,4
        .BYTE 4,4,4,4,4,4,4,4
