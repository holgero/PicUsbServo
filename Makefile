# USB Firmware for PICs
# Top level Makefile, runs make in subdirectories.
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

all: 18f13k50 18f2550 examples

18f13k50:
	$(MAKE) -C 18f13k50 clean all

18f2550:
	$(MAKE) -C 18f2550 clean all

examples: 18f2550 18f13k50
	$(MAKE) -C examples

clean:
	$(MAKE) -C 18f13k50 clean
	$(MAKE) -C 18f2550 clean

.PHONY: all clean checkVIDPID 18f13k50 18f2550 examples
