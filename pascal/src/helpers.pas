

procedure CRT_Write_LocStr(b: byte);
var z: word;
  tmpstr: ^String;
begin;
  z := (b-1)*$28;
//  tmpstr := Pointer(loc_string_1) + z;
  CRT_Write(tmpstr);
end;


procedure CRT_Writeln_LocStr(b: byte);
begin;
  CRT_Write_LocStr(b);
  CRT_NewLine;
end;


procedure CRT_Writeln2_LocStr(b: byte);
begin;
  CRT_Writeln_LocStr(b);
  CRT_NewLine;
end;


procedure CRT_WriteCentered_LocStr(r: byte; b: byte);
var z: word;
  tmpstr: ^String;
begin;
  z := (b-1)*$28;
//  tmpstr := Pointer(loc_string_1) + z;
  CRT_WriteCentered(r, tmpstr);
end;


// produce some sound effect or something while waiting
procedure effectWait ();
begin;
    WaitFrames(120);
end;



function CRT_ReadKeyOrJoystick():byte;
var z: char;
begin;
    result := kbcode;
    repeat until (not CRT_KeyPressed) or (result<>kbcode);
    repeat
      z := checkKeyAndStick();
    until CRT_KeyPressed or (z = #$0c) or (z = #14) or (z = #15) or (z = #06) or (z = #07);
    if byte(z) <> 0 then
      result := byte(z)
    else
      result := kbcode;
end;


function CRT_ReadKeyOrFire():byte;
begin;
    result := kbcode;
    repeat until (not CRT_KeyPressed) or (result<>kbcode);
    repeat until CRT_KeyPressed or (checkKeyAndStick = #$0c);
    result := kbcode;
end;


// procedure waitForKey();
// var k:byte;
// begin
//     k := CRT_WhereY();
//     k := k + 2;
//     CRT_WriteCentered(k, waitKey_String);
//     CRT_ReadKeyOrFire();
// end;



procedure CRT_NewLine2();
begin
  CRT_NewLine();
  CRT_NewLine();
end;

procedure CRT_Writeln2 (S: String);
begin
  CRT_Write(S);
  CRT_NewLine2();
end;


procedure CRT_Writeln (S: String);
begin
  CRT_Write(S);
  CRT_NewLine();
end;


function getAnswerChar(Akey:byte; Bkey:byte; A:char; B:char): byte;
var x, y: byte;
  ch: byte;
  answer: char;
begin
  x := CRT_WhereX;
  y := CRT_WhereY;
  answer := A;
  repeat
    CRT_GotoXY(x, y);
    CRT_Write(answer);
    CRT_Write(' '~);
    ch := CRT_ReadKeyOrJoystick();
    if ch = $0c then break;
    if (ch = 14) or (ch = Akey) then answer := A;
    if (ch = 15) or (ch = Bkey) then answer := B;
  until false;
  if answer = A then result := 0 else result := 1;
end;


// 0 = N, 1 = Y
// function getYesNo:   byte;
// begin
//     result := getAnswerChar(N_keycode, Y_keycode, N_charcode, Y_charcode);
// end;


const
  FAST_ADJUST_DELAY: byte = 16;


function readValue(minValue: SMALLINT; maxValue: SMALLINT): SMALLINT; //overload;
var
  value: integer; // To ensure that +step does not overflow
  step: SMALLINT;
  x, y: byte;
  tmpch, ch: char;
  curDelay: byte;
  fastAdjustCounter: byte;
begin
  x := CRT_WhereX;
  y := CRT_WhereY;

  value := minValue;
  step := 1;
  fastAdjustCounter := 0;
  curDelay := FAST_ADJUST_DELAY;
  CRT_Write(value);
  CRT_Write('    '~);
  ch := char(CRT_ReadKeyOrJoystick()); //this will wait for release
  repeat
    ch := checkKeyAndStick();

    if byte(ch) = $0c then break;

    if byte(ch) = 14 then
    begin
      if fastAdjustCounter = 0 then
      begin
        value := value + step;
        if value > maxValue then
          value := maxValue;
        if curDelay > 2 then
          curDelay := curDelay - 1
        else
          step := 2;
        fastAdjustCounter := curDelay;
      end;
    end
    else if byte(ch) = 07 then
    begin
      value := value + 500;
      if value > maxValue then
        value := maxValue;
      // wait
      repeat;
          tmpch := checkKeyAndStick ();
      until tmpch <> ch; // wait for key release or so..
    end
    else if byte(ch) = 06 then
    begin
      value := value - 500;
      if value < minValue then
        value := minValue;
      // wait
      repeat;
          tmpch := checkKeyAndStick ();
      until tmpch <> ch; // wait for key release or so..
    end
    else if byte(ch) = 15 then
    begin
      if fastAdjustCounter = 0 then
      begin
        value := value - step;
        if value < minValue then
          value := minValue;
        if curDelay > 2 then
          curDelay := curDelay - 1
        else
          step := 2;
        fastAdjustCounter := curDelay;
      end;
    end
    else
    begin
      fastAdjustCounter := 0;
      curDelay := FAST_ADJUST_DELAY;
      step := 1;
    end;

    if fastAdjustCounter > 0 then
      fastAdjustCounter := fastAdjustCounter-1;

    CRT_GotoXY(x, y);
    CRT_Write(value);
    CRT_Write('    '~);
    WaitFrame;
  until false;

  result := value;
end;


// procedure loadGangster(g: byte);
// var b, k:   byte;
// {$ifndef CART}
//   p: cardinal; // save a few bytes..
// {$endif}
// begin;
//     {$ifdef CART}
//     xBiosOpenFile(gangsterFilename);
//     // NO IDEA how to do this differently, loading with setlength did not work
//     // p := g SHL 8;
//     // xBiosSetFileOffset(p);
//     // xBiosSetLength(255-17);
//     // xBiosLoadData(Pointer(VARBLOCK1+$470));
//     for b := 0 to g-1 do
//     begin;
//       for k := 0 to 255-17 do // $470-$55e incl.
//         Poke(VARBLOCK1+$470+k, xBiosGetByte); // pointer to buf_gangsterText1
//       for k := 0 to 17-1 do
//         xBiosGetByte; // do not save anywhere
//     end;

//     {$else}

//     xBiosOpenFile(gangsterFilename);
//     p := g SHL 8;
//     xBiosSetFileOffset(p);
//     xBiosSetLength(255);
//     for k := 0 to 255-17 do // $470-$55e incl.
//         Poke(VARBLOCK1+$470+k, xBiosGetByte); // pointer to buf_gangsterText1
//     {$endif}

//     CRT_Writeln(buf_gangsterName);
//     CRT_NewLine;
//     CRT_Writeln(buf_gangsterText1);
//     CRT_Writeln(buf_gangsterText2);
//     CRT_Writeln(buf_gangsterText3);
//     CRT_Writeln(buf_gangsterText4);
//     CRT_Writeln(buf_gangsterText5);
// end;


