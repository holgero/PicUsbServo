# USB bootloader for PICs
# Makefile for the PIC 18f13k50, creates bootloader.hex
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

OBJECTS=main.o vectors.o

all: example.hex

example.hex: $(OBJECTS)
	gplink -o example.hex -a inhx32 -m $(OBJECTS) -s 18f13k50_bootloader.lkr

%.o : %.asm
	gpasm -c -p p18f13k50 -r dec -w 2 $<

clean:
	rm -f *.o *.map *.lst *.cod *.hex

.PHONY: all clean
