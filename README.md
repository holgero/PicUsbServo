PicUsbBootloader
================

An USB bootloader for PICs. The bootloader firmware is meant to be
compatible with the bootloader that comes factory-loaded on the
"PICDEM Full Speed USB" demo board. This allows to use it
with the fsusb implementation from Rick Luddy
( http://www.internetking.org/fsusb/ ).

## Implementation State

The commands READ_VERSION (0x00), READ_FLASH (0x01), WRITE_FLASH (0x02)
ERASE_FLASH (0x03), READ_CONFIG (0x06) have been implemented.

READ_EEDATA (0x04), WRITE_EEDATA (0x05), WRITE_CONFIG (0x07),
UPDATE_LED (0x32) and RESET (0xFF) are not implemented.

## Usage

Flash your PIC with the bootloader.hex. To change the firmware in the PIC
pull down RB7 while connecting the PIC to the USB port. This enters
bootloader mode and the firmware can be changed with fsusb (see
http://www.internetking.org/fsusb/ ). You will need to adapt fsusb to
search for the right VID/PID (fsusb_vendorID, fsusb_productID in fsusb.c).

(I plan to write my own bootloader host program in java to replace fsusb,
but this is a statement about the future, of course. :-))

The bootloader occupies the first page of the PIC (0x0000 - 0x0800). The
interrupt vectors are remapped to 0x0800, 0x0808 and 0x0818.
See the example subdirectory for a linker script you can use with your
application. It contains also vectors.asm with a declaration of the
remapped interrupt vectors.

## Building

To build: Run make in the top level directory like this:

	$ make VID=<vid> PID=<pid>

Where <vid> is the vendor id and pid is the product id you want to use for
your device in hexadecimal without a leading "0x".
Example:

	$ make VID=0000 PID=0000

This will run make in the subdirectories, which in turn runs gpasm to
compile and link the assembler sources to a .hex file.

There is a CI build of the firmware at travis-ci: http://travis-ci.org/holgero/PicUsbBootloader

## Directories

18f13k50	Bootloader for the PIC 18f13k50 (works only on 18f13k50,
		the 18f14k50 has a different block write size).

## License

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
