{$DEFINE ROMOFF}    // http://mads.atari8.info/doc/en/syntax/#romoff
{$DEFINE NOROMFONT}

program DERTUNNEL;

{$define basicoff}
{$librarypath '../MP/blibs/'}
{$librarypath '../MP/base/'}
{$librarypath '../MP/lib/'}

{$r pascal/resources_main.rc}

uses atari, pmg, crt, rmt, sysutils, xbios, b_utils, b_system, b_crt;

const
    {$i pascal/const_main.inc}

var
    lastLocation:   byte;
    msx: TRMT;
    playMusic: byte;
    loccolbk: byte;
    loccolpf0: byte;
    loccolpf1: byte;
    loccolpf2: byte;
    gameends: byte;
    finalfname:   String[16];

type
    XString =   String[15];
    YString =   String[40];


procedure musicproxy();
begin;
    if playMusic = 1 then
        msx.play();
end;


{$I pascal/helpers_input.pas}
{$I pascal/helpers.pas}
{$I pascal/interrupts.inc}
{$I pascal/xbaplib.pas}


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


{$I pascal/console.pas} 


procedure clearMemory();
begin;
    // FillChar (Pointer(MALE), $1800, 0);
    // FillChar (Pointer(LOCATION_ADR), $1000, 0);
    // FillChar (Pointer(VARBLOCK1), $44, 0);
end;



var
    ch: char;
    i, j,k : byte;
    fadr, madr, iadr: word;
    dispadr: word;
begin
    DMACTL := $22;
    // asm;
    //     pha
    //     jsr xbios.xBIOS_SET_DEFAULT_DEVICE
    //     lda #$00
    //     sta xbios.xIRQEN
    //     pla
    // end;

    randomize;
    SystemOff;

    playMusic := 0;
    if playMusic = 99 then
        musicproxy();   // force inclusion of musicproxy, never actually called here

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
    msx.modul  := pointer(rmt_modul);
    playMusic := 0; // for now
 
    EnableDLI(@dli_menu_circle);
    DLISTL := DL_CIRCLES_ADR;



for j := 1 to 96 do 
    begin
        dispadr := DL_CIRCLES_ADR + 4;

        // --- Male Part ---
        k := 192 - j;
        if k >= 102 then madr := MALE_ADDRESS + k * 40 + 16 else madr := MALE_ADDRESS + k * 40;

        for i := 0 to j-1 do
        begin 
            DPoke (dispadr, madr);
            if k = 101 then madr := madr + 56 else madr := madr + 40;
            inc(k);
            dispadr := dispadr + 3;            
        end;

        // --- Black Gap ---
        for i := j to 192-j-2 do
        begin 
            DPoke (dispadr, MALE_ADDRESS + 190 * 40 + 16);
            dispadr := dispadr + 3;            
        end;

        // --- Female Part ---
        k := 0;
        fadr := FEMALE_ADDRESS;

        for i := 192-j-1 to 191 do
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
