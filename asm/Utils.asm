RTCLOK60 = $0014

; ---------------------------------------------------------------------------
; FRAME_WAIT  –  wait for next frame (RTCLOK60 increments every 1/60th of a second)
; ---------------------------------------------------------------------------

FRAME_WAIT
        LDA RTCLOK60    ; wait for next frame (RTCLOK60 increments every 1/60th of a second)
_WAIT_LOOP
        CMP RTCLOK60
        BEQ _WAIT_LOOP
        RTS

; ---------------------------------------------------------------------------
; FADE  –  fade out by decrementing COLPF1 (white) to black
; ---------------------------------------------------------------------------

FADE    
        LDX #60      ; wait 1 second before starting fade (60 frames at 60Hz)
_SEC_WAIT_LOOP
        JSR FRAME_WAIT
        DEX            
        BNE _SEC_WAIT_LOOP

_FADE    
        LDX #5          ; 5 steps in the fade outer loop (0.1 second at 60Hz)
_5STEPS_LOOP
        JSR FRAME_WAIT
        DEX            ; decrement fade step counter
        BNE _5STEPS_LOOP

        DEC $02C5      ; decrement COLPF1 (white) to fade out
        BNE _FADE
        RTS

