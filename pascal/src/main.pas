{$DEFINE ROMOFF}    // http://mads.atari8.info/doc/en/syntax/#romoff
{$DEFINE NOROMFONT}

program DERTUNNEL;

{$define basicoff}
{$librarypath '..\..\..\MP/blibs/'}
{$librarypath '..\..\..\MP/base/'}
{$librarypath '..\..\..\MP/lib/'}

{$r ./resources_main.rc}
{$r ./resources_data.rc}


uses atari, pmg, aplib, xbios, crt, b_utils, rmt, sysutils, b_system, b_crt;

const
    {$i const_main.inc}
    {$i const_data.inc}

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
  ScrWidth  = 40;
  ScrHeight = 25;                 // Atari 8-bit default text mode is 40x24;
                                   // set this to 24 if targeting real Atari hardware
  CenterX   = ScrWidth  div 2;    // 20
  CenterY   = ScrHeight div 2;    // 12


procedure fillTunnel();
var
  x, y : byte;
  dist : byte;
  curMem: word;
begin
    curMem := CROSS_ADDRESS;
  for y := 0 to ScrHeight - 1 do
    for x := 0 to ScrWidth - 1 do
    begin
      dist := Abs(x - CenterX) + Abs(y - CenterY) + 8;
        Poke(curMem, dist);
        Inc(curMem);
    end;
end;

procedure setChar(p:  byte; v: byte);
var i: byte;
    curAdr: word;
begin;
    curAdr := FONT_ADDRESS + p*8;
    for i := 0 to 7 do
    begin; 
        Poke(curAdr, v);
        curAdr := curAdr + 1;
    end; 
end; 

const 
    TUNNEL_THICKNESS = 1;


const 
    text_tunnel = 1;
    text_geburt = 2;
    text_leben = 3;
    text_tod = 4;

procedure showText(b: byte);
var k: byte;
begin;
    DLISTL := DL_TEXT_ADR;
    if b = text_tunnel then unAPL(Pointer(ADR_DIEGEBURT), Pointer(CROSS_ADDRESS));
    if b = text_geburt then unAPL(Pointer(ADR_DERTUNNEL), Pointer(CROSS_ADDRESS));
    if b = text_leben then unAPL(Pointer(ADR_DASLEBEN), Pointer(CROSS_ADDRESS));
    if b = text_tod then unAPL(Pointer(ADR_DERTOD), Pointer(CROSS_ADDRESS));

    for k := 0 to 63 do 
    begin;
        atari.colpf1 := k shr 2;
        Waitframe;
    end; 
    Waitframes(60);
    for k := 63 downto 0 do 
    begin;
        atari.colpf1 := k shr 2;
        Waitframe;
    end; 
end;




var
  x, y, ly: byte;
  has_white: boolean;
  base_src, base_dst: word;
  src_ptr, dst_ptr: word;

const
  BYTES_PER_LINE = 40;
  WHITE_BYTE = $FF;
  BLACK_BYTE = $00;


var
    ch: char;
    i, j,k, s : byte;
    fadr, madr, iadr: word;
    dispadr: word;
    curAdr,tgtAdr: word;
begin
    DMACTL := $22;

    randomize;
    SystemOff;
    playMusic := 0;
    if playMusic = 99 then
        musicproxy();   // force inclusion of musicproxy, never actually called here

    clearMemory();

    asm;
        lda #$00
        sta atari.colbk
        lda #$0e
        sta atari.colpf0
        lda #$0e
        sta atari.colpf1
        lda #$0e
        sta atari.colpf2
        lda #$00
        sta atari.colpf2
    end;

    msx.player := pointer(rmt_player);
    msx.modul  := pointer(rmt_modul);
    playMusic := 0; // for now






    unAPL(Pointer(ADR_MAN), Pointer(MALE_ADDRESS));
    unAPL(Pointer(ADR_WOMAN), Pointer(FEMALE_ADDRESS));

    EnableDLI(@dli_menu_circle);
    DLISTL := DL_CIRCLES_ADR;

    asm;
        lda #$00
        sta atari.colbk
        lda #$74
        sta atari.colpf0
        lda #$34
        sta atari.colpf1
        lda #$0e
        sta atari.colpf2
    end; 

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

        if j < 39 then 
        begin;
            for i := 0 to 40 do 
            begin 
                k := Peek (fadr);
                k := k + (k shr 1);
                Poke (fadr, k);
                fadr := fadr + 1;
            end;

            if j < 33 then begin 
                for i := 0 to 40 do 
                begin 
                    k := Peek (madr);
                    k := k + (k shl 1);
                    Poke (madr, k);
                    madr := madr + 1;
                end;
            end 
            else 
            begin 
                for i := 0 to 40 do 
                begin 
                    k := Peek (fadr-40-120-1+i);
                    Poke (madr, k);
                    madr := madr + 1;
                end;
            end;
        end 
        else 
        begin 
            for i := 0 to 40 do 
            begin 
                Poke (madr, 0);
                madr := madr + 1;
            end;

            for i := 0 to 40 do 
            begin 
                Poke (fadr, 0);
                fadr := fadr + 1;
            end;
        end; 

        Waitframe;
    end;

// -- zoom out

    dispadr := DL_CIRCLES_ADR + 4;
    tgtadr := CROSS_ADDRESS;
    for i := 0 to 191 do
    begin 
        curadr := DPeek (Pointer(dispadr));
        Move (Pointer(curadr), Pointer(tgtadr), 40);
        dispadr := dispadr + 3;
        tgtadr := tgtadr + 40;
        if i = 101 then tgtadr := tgtadr+16;
    end;
    WaitFrames(250);

    DLISTL := DL_TEXT_ADR;

    asm;
        lda #$00
        sta atari.colbk
        lda #$00
        sta atari.colpf0
        lda #$00
        sta atari.colpf1
        lda #$00
        sta atari.colpf2
        lda #$00
        sta atari.colpf3
    end;

    // showText(text_tunnel);
    // showText(text_geburt);
    // showText(text_leben);
    // showText(text_tod);



//--- tunnel 
    DLISTL := DL_TUNNEL_ADR;
    unAPL(Pointer(ADR_TUNNEL), Pointer(MALE_ADDRESS));
    SetCharset (Hi(FONT_ADDRESS));


    asm;
        lda #$00
        sta atari.colbk
        lda #$0e
        sta atari.colpf0
        lda #$0e
        sta atari.colpf1
        lda #$0e
        sta atari.colpf2
        lda #$00
        sta atari.colpf2
    end;



    curAdr := FONT_ADDRESS;
    for i := 0 to $20 do 
        setChar(i, 0);

    s := 2;
    for i := s to TUNNEL_THICKNESS-1+s do
        setChar(i, 255);

    i := s;
    k := 0;
    repeat;
        setChar(i, 0);
        j := i+TUNNEL_THICKNESS+1;
        if j > $0f then j := j - $10; 
        setChar(j, 255);


        Inc(i, 1);
        if i = $10 then begin;
            i := 0;
            Inc(k);
        end;
        // for s := 0 to 200 do
        // begin;
        //     Waitframes(20);
        //     if (s and $01) = 1 then 
        //         DLISTL := DL_TUNNEL_ADR
        //     else 
        //         DLISTL := DL_ZOOMOUT_ADR;
        // end;
        Waitframe;
        Waitframe;
    WaitFrames(250);
        
    until k = 20;



    CRT_ReadKeyOrFire();
    DisableDLI;
    Waitframes(100);
 
end.
