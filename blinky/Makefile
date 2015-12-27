PROJ=blinky

all: $(PROJ).bin

%.blif: %.v
	yosys -p 'synth_ice40 -top top -blif $@' $<

%.txt: %.blif icestick.pcf
	arachne-pnr -d 1k -o $@ -p icestick.pcf $<

%.bin: %.txt
	icepack $< $@

prog: $(PROJ).bin
	iceprog $<

clean:
	rm -f *.blif *.txt *.bin

.PHONY: all prog clean
