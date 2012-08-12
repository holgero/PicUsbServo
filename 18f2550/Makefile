# USB Firmware for PICs
# Makefile for the PIC 18f2550, creates firmware.hex.
#
# Copyright (C) 2012 Holger Oehm
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

OBJECTS=usb.o main.o descriptor.o

%.o : %.asm
	gpasm -c -p p18f2550 -r dec -w 2 --define VID=0x$(VID) --define PID=0x$(PID) $<

all: firmware.hex

firmware.hex: $(OBJECTS)
	gplink -o firmware.hex -a inhx32 -m $(OBJECTS)

clean:
	rm -f *.o *.map *.lst *.cod *.hex

.PHONY: all clean
