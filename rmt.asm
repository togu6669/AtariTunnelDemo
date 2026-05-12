; RMT integration wrapper for the tunnel demo.
;
; Default mode is a silent stub so the project still builds cleanly.
; To enable real RMT playback:
;   1. Export or copy an RMT player source file into this folder as:
;        rmt_player.asm
;   2. Export or copy your song/module source file into this folder as:
;        rmt_song.asm
;   3. Set RMT_ENABLED = 1 below.
;   4. If your export uses different label names than the common ones,
;      adjust RMT_PLAYER_ENTRY and RMT_SONG_DATA in the enabled block.
;
; Common RMT source-export conventions:
;   - player entry label: RASTERMUSICTRACKER
;   - song/module label:  MODUL
;   - init:              jsr RASTERMUSICTRACKER
;                        A = start song line (usually 0)
;                        X/Y = low/high bytes of song/module address
;   - play frame:        jsr RASTERMUSICTRACKER+3
;   - stop:              jsr RASTERMUSICTRACKER+9

RMT_ENABLED = 0

.IF RMT_ENABLED
        ICL "rmt_player.asm"
        ICL "rmt_song.asm"

RMT_PLAYER_ENTRY = RASTERMUSICTRACKER
RMT_SONG_DATA    = MODUL

MUSIC_INIT
        LDA #0
        LDX #<RMT_SONG_DATA
        LDY #>RMT_SONG_DATA
        JSR RMT_PLAYER_ENTRY
        RTS

MUSIC_PLAY_FRAME
        JSR RMT_PLAYER_ENTRY+3
        RTS

MUSIC_STOP
        JSR RMT_PLAYER_ENTRY+9
        RTS
.ELSE
MUSIC_INIT
        RTS

MUSIC_PLAY_FRAME
        RTS

MUSIC_STOP
        RTS
.ENDIF
