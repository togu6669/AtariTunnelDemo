
# tools
MP=F:\Prog\Atari\MP\bin\windows\mp.exe
MADS=F:\Prog\Atari\MADS\bin\windows_x86_64\mads.exe
BASE=F:\Prog\Atari\MP\base

# output
RELEASE_DIR=..\..\build
OUTPUT_DIR=$(RELEASE_DIR)

ASM=$(OUTPUT_DIR)/main.a65
XEX=$(OUTPUT_DIR)/main.xex



all: compile_main \
	run

compile_main:
	$(MP) main.pas -code:0c00 -o:$(ASM)
	$(MADS) $(ASM) -x -i:$(BASE) -o:$(XEX)
	
run:
	F:\Prog\Atari\Altirra\Altirra64.exe $(XEX)

	

