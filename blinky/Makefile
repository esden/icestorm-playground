all: blinky.bin

blinky.blif: blinky.v
	yosys -p 'synth_ice40 -top top -blif blinky.blif' blinky.v

blinky.txt: blinky.blif icestick.pcf
	arachne-pnr -d 1k -o blinky.txt -p icestick.pcf blinky.blif

blinky.bin: blinky.txt
	icepack blinky.txt blinky.bin

prog: blinky.bin
	iceprog blinky.bin

clean:
	rm -f blinky.blif blinky.txt blinky.bin

.PHONY: all prog clean
