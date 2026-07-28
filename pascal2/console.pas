
Var 
    consoleState: byte;

 
Procedure WaitFrames(frames: byte);
Begin
    While frames>0 Do
        Begin
            WaitFrame;
            Dec(frames);
        End;
End;



