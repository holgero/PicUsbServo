PicUsbFirmware
==============

USB Firmware for PICs

## Building

To build: Run make in the top level directory like this:

	$ make VID=<vid> PID=<pid>

Where <vid> is the vendor id and pid is the product id you want to use for
your device in hexadecimal without a leading "0x".
Example:

	$ make VID=0000 PID=0000

This will run make in the subdirectories, which in turn runs gpasm to
compile and link the assembler sources to a .hex file.

## Directories

18f13k50	Firmware for the PIC 18f13k50 (maybe works on the complete
		PIC family 18f1xk50, maybe not)
18f2550		Firmware for the PIC 18f2550 (maybe works on the complete
		PIC family 18f[24][45]5x, maybe not)
