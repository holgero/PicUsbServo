PicUsbFirmware
==============

USB Firmware for PICs

This project is a spin-off of the [XFD](https://github.com/holgero/XFD)
(eXtreme Feedback Device) project. This project focuses on the firmware
for the PICs, if you are looking for schematics, host programs etc. you may
want to have a look at the XFD project. Also this project is licensed under
a less restrictive license (the Apache License 2.0).

## Building

To build: Run make in the top level directory like this:

	$ make VID=<vid> PID=<pid>

Where <vid> is the vendor id and pid is the product id you want to use for
your device in hexadecimal without a leading "0x".
Example:

	$ make VID=0000 PID=0000

This will run make in the subdirectories, which in turn runs gpasm to
compile and link the assembler sources to a .hex file.

There is a CI build of the firmware at travis-ci: http://travis-ci.org/holgero/PicUsbFirmware

## Directories

18f13k50	Firmware for the PIC 18f13k50 (maybe works on the complete
		PIC family 18f1xk50, maybe not)

18f2550		Firmware for the PIC 18f2550 (maybe works on the complete
		PIC family 18f[24][45]5x, maybe not)

examples/18f13k50	example project that uses the 18f13k50 firmware

examples/18f2550	example project that uses the 18f2550 firmware

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
