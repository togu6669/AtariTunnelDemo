
        ORG $B0
DST0PTR .WORD 0
        
        ORG $2000

DATA16BIT   = $5000

START
; odejmij 40 od pointera DST0PTR i zachowal go pod zmienna DATA16BIT        
        LDA DATA16BIT
        SBC #$28
        STA DATA16BIT
        LDA DATA16BIT+1
        SBC #$00
        STA DATA16BIT+1


 ; adres startowy programu
        ORG $02E0
        .WORD START
