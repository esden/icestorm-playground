PROJ = ws2812
PIN_DEF = hx8kboard.pcf
DEVICE = 8k

all: $(PROJ).bin

%.blif: %.v
#	yosys uart.ys
	yosys -p 'synth_ice40 -top top -blif $@' $^

%.asc: $(PIN_DEF) %.blif
	arachne-pnr -d $(DEVICE) -o $@ -p $^

%.bin: %.asc
	icepack $< $@

prog: $(PROJ).bin
	iceprog $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).bin

.PHONY: all prog clean
