
# tools
MP=../../bin/mp_osx
MADS=../../bin/mads_osx
BASE=../../tools/Mad-Pascal/base

ATR_BIN=../../bin/atr_osx
dir2atr=../../bin/dir2atr_osx

# packing of assets
APULTRA_BIN=../../bin/apultra_osx

# output
RELEASE_DIR=../release
OUTPUT_DIR=$(RELEASE_DIR)/output/
ATR_DIR=../atr/

ASM=$(OUTPUT_DIR)/main.a65
XEX=$(OUTPUT_DIR)/main.xex


BLANK_ATR=$(ATR_DIR)/180k_empty.atr
XBOOT=$(ATR_DIR)/xboot.obx
ATR=$(OUTPUT_DIR)/output.atr
ATR_ASSETS=../release/atr.assets/$(LOCATION)/

# packing of xex
EXOMIZER_BIN=../../bin/exomizer_osx
AUTOXEX=$(OUTPUT_DIR)/autorun.xex
EXO=$(OUTPUT_DIR)/exomized
AUTOEXO=$(OUTPUT_DIR)/exomizedauto

FREE_SPACE = $(shell $(ATR_BIN) $(ATR) ls -l | grep free)



all:
	rm -rf $(RELEASE_DIR)
	$(MAKE) atr

atr: clean prepare_atr_folder\
	compile_main \
	build_atr info \
	run
 
clean:
	# rm -rf $(RELEASE_DIR)
	mkdir -p $(RELEASE_DIR)
	rm -rf $(OUTPUT_DIR)
	mkdir -p $(OUTPUT_DIR)
	rm -f $(AUTOXEX)
	rm -f $(XEX)
	rm -f $(AUTOEXO)
	rm -f $(EXO)
	rm -f $(ATR)
	cp $(BLANK_ATR) $(ATR)

prepare_atr_folder:
	rm -rf $(ATR_ASSETS)
	mkdir -p $(ATR_ASSETS)
	cp $(ATR_DIR)/xbios.com $(ATR_ASSETS)
	echo cp ../assets/final.xex $(ATR_ASSETS)/final.xex
 

compile_main:
	$(MP) main.pas -code:0c00 -o:$(ASM)  -define:LOCATION_$(LOCATION) -define:CHEAT
	$(MADS) $(ASM) -x -i:$(BASE) -o:$(XEX)
	cp $(XEX) $(ATR_ASSETS)/XAUTORUN


build_atr:
	$(dir2atr) -B $(XBOOT) -D $(ATR) $(ATR_ASSETS) # needs XAUTORUN


info:
	@echo $(FREE_SPACE)

run:
	echo /Applications/Atari800MacX.app/Contents/MacOS/Atari800MacX $(ATR)

