{$DEFINE ROMOFF} // http://mads.atari8.info/doc/en/syntax/#romoff
{$DEFINE NOROMFONT}
program NUCUWARS;
{$define basicoff}
{$librarypath '../../tools/Mad-Pascal/blibs/'}
{$librarypath '../../tools/Mad-Pascal/base/'}
{$librarypath '../../tools/Mad-Pascal/lib/'}
{$ifdef CART}
    {$r ./resources_car.rc}
{$else}
    {$r ./resources_car.rc}
{$endif}
// NOTE: b_maxFlash8Mb.pas CANNOT be found due to lower/upper case.
// for this to work, copy it to b_maxflash8mb.pas in tools/Mad-Pascal-1.7.2/blibs
uses atari, pmg, xbios, crt, b_utils, rmt, sysutils, b_system, b_crt;
{$ifdef CART}
const
    {$i const_car.inc}
    {$i b_maxflash.pas}
{$else}
const
    {$i const_car.inc}
    // fix return of checkSavedGame...
{$endif}
var
    lastLocation: byte;
    msx: TRMT;
    playMusic: byte;
    loccolbk: byte;
    loccolpf0: byte;
    loccolpf1: byte;
    loccolpf2: byte;
    gameends: byte;
    finalfname: String[16];
type
    XString = String[15];
    YString = String[40];
procedure musicproxy();
begin;
    if playMusic = 1 then
        msx.play();
end;
{$I helpers_input.pas}
{$I helpers.pas}
{$I interrupts.inc}
{$I xbaplib.pas}
procedure loadxAPL(var fname: TString; outputPointer: pointer);
var msxstatus: byte;
begin;
    {$ifdef CART}
    xbunAPL(fname, outputPointer);
    {$else}
    msxstatus := playMusic;
    if playMusic = 1 then
        msx.stop();
    playMusic := 0;
    xbunAPL(fname, outputPointer);
    playMusic := msxstatus;
    {$endif}
end;
{$I console.pas}
procedure clearMemory();
begin;
    // FillChar (Pointer(MALE), $1800, 0);
    // FillChar (Pointer(LOCATION_ADR), $1000, 0);
    // FillChar (Pointer(VARBLOCK1), $44, 0);
end;
const
    // Two-phase motion for "posj" (how far the two halves have closed the
    // gap, 1 = fully apart, 96 = fully touching):
    //
    //   Phase 1 "the fall"   - frames 0..39   - smooth, MONOTONIC climb
    //                          from 1 up to 96 (quadratic ease-in, i.e. a
    //                          real gravity-style acceleration). No bounce
    //                          here - it has to actually reach the meeting
    //                          line first.
    //   Phase 2 "bounce 1"   - frames 40..62  - leaves 96, opens back up to
    //                          a gap of 16 lines, falls back to 96.
    //   Phase 3 "bounce 2"   - frames 63..77  - opens to 8 lines, back to 96.
    //   Phase 4 "bounce 3"   - frames 78..86  - opens to 4 lines, back to 96.
    //   Phase 5 "settle"     - frames 87..96  - holds at 96.
    //
    // Every bounce is a real parabolic arc (posj = 96 - amplitude*4*u*(1-u)),
    // i.e. actual projectile motion, and each one is smaller/quicker than
    // the last - a ball hitting the ground at "posj=96", bouncing, and
    // coming to rest there, instead of bouncing somewhere on the way down.
    //
    // HARD CEILING - DO NOT PUT VALUES ABOVE 96 IN THIS TABLE:
    // dispadr writes exactly (posj) + (191-2*posj, if >0) + (posj+1) entries
    // per frame. For posj<=95 that always sums to 192 - exactly the size of
    // the DL_CIRCLES_ADR buffer (192 entries * 3 bytes). At posj=96 it's
    // already 193 (a harmless 1-entry/3-byte overlap that exists in the
    // original code too). Above 96 the gap term clamps to 0 but male+female
    // keeps growing (2*posj+1), so e.g. posj=120 writes 241 entries - 723
    // bytes into a 576-byte buffer, smashing ~150 bytes past the end of the
    // display list. That's the crash. 96 is the meeting point, not a
    // tunable amplitude - a bigger-looking bounce has to come from dipping
    // further BELOW 96 (toward 1), not from going above it.
    BOUNCE_FRAMES = 97;
    BOUNCE_J : array [0..BOUNCE_FRAMES-1] of byte = (
        1, 1, 1, 2, 2, 3, 3, 4, 5, 6, 7, 9,
        10, 12, 13, 15, 17, 19, 21, 24, 26, 29, 31, 34,
        37, 40, 43, 47, 50, 54, 57, 61, 65, 69, 73, 78,
        82, 87, 91, 96, 93, 91, 89, 87, 85, 84, 82, 81,
        81, 80, 80, 80, 80, 81, 81, 82, 84, 85, 87, 89,
        91, 93, 96, 94, 92, 91, 90, 89, 88, 88, 88, 88,
        89, 90, 91, 92, 94, 96, 94, 93, 92, 92, 92, 92,
        93, 94, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96,
        96
    );
var
    ch: char;
    i, j, k : byte;
    frame, posj: byte;
    fadr, madr, iadr: word;
    dispadr: word;
begin
    DMACTL := $22;
    asm;
        pha
        jsr xbios.xBIOS_SET_DEFAULT_DEVICE
        lda #$00
        sta xbios.xIRQEN
        pla
    end;
    randomize;
    SystemOff;
    playMusic := 0;
    if playMusic = 99 then
        musicproxy(); // force inclusion of musicproxy, never actually called here
    clearMemory();
    asm;
        lda #$00
        sta atari.colbk
        lda #$74
        sta atari.colpf0
        lda #$34
        sta atari.colpf1
        lda #$54
        sta atari.colpf2
    end;
    msx.player := pointer(rmt_player);
    msx.modul := pointer(rmt_modul);
    playMusic := 1; // for now
    EnableDLI(@dli_menu_circle);
    DLISTL := DL_CIRCLES_ADR;
for frame := 0 to BOUNCE_FRAMES-1 do
    begin
        posj := BOUNCE_J[frame];
        dispadr := DL_CIRCLES_ADR + 4;
        // --- Male Part ---
        k := 192 - posj;
        if k >= 102 then madr := MALE_ADDRESS + k * 40 + 16 else madr := MALE_ADDRESS + k * 40;
        for i := 0 to posj-1 do
        begin
            DPoke (dispadr, madr);
            if k = 101 then madr := madr + 56 else madr := madr + 40;
            inc(k);
            dispadr := dispadr + 3;
        end;
        // --- Black Gap ---
        for i := posj to 192-posj-2 do
        begin
            DPoke (dispadr, MALE_ADDRESS + 190 * 40 + 16);
            dispadr := dispadr + 3;
        end;
        // --- Female Part ---
        k := 0;
        fadr := FEMALE_ADDRESS;
        for i := 192-posj-1 to 191 do
        begin
            DPoke (dispadr, fadr);
            if k = 101 then fadr := fadr + 56 else fadr := fadr + 40;
            inc(k);
            dispadr := dispadr + 3;
        end;
        Waitframe;
    end;
    for j := 1 to 82 do
    begin
        dispadr := DL_CIRCLES_ADR + 4;
        // --- Male Part ---
        k := 96 - j;
        if k >= 102 then madr := MALE_ADDRESS + k * 40 + 16 else madr := MALE_ADDRESS + k * 40;
        for i := 0 to 95 do
        begin
            DPoke (dispadr, madr);
            if k = 101 then madr := madr + 56 else madr := madr + 40;
            inc(k);
            dispadr := dispadr + 3;
        end;
        // --- Female Part ---
        k := j;
        if k >= 102 then fadr := FEMALE_ADDRESS + k * 40 + 16 else fadr := FEMALE_ADDRESS + k * 40;
        for i := 95 to 191 do
        begin
            DPoke (dispadr, fadr);
            if k = 101 then fadr := fadr + 56 else fadr := fadr + 40;
            inc(k);
            dispadr := dispadr + 3;
        end;
        Waitframe;
    end;
    // --- Fill/Fade Effect ---
    for j := 0 to 96 do
    begin
        k := 110 - j;
        if k >= 102 then madr := MALE_ADDRESS + k * 40 + 16 else madr := MALE_ADDRESS + k * 40;
        k := 80 + j;
        if k >= 102 then fadr := FEMALE_ADDRESS + k * 40 + 16 else fadr := FEMALE_ADDRESS + k * 40;
        for i := 0 to 40 do
        begin
            k := Peek (madr);
            k := k + (k shl 1);
            Poke (madr, k);
            madr := madr + 1;
        end;
        for i := 0 to 40 do
        begin
            k := Peek (fadr);
            k := k + (k shr 1);
            Poke (fadr, k);
            fadr := fadr + 1;
        end;
        Waitframe;
    end;
   
    CRT_ReadKeyOrFire();
    DisableDLI;
    Waitframes(100);
end.