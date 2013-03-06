# PIC USB servo controller
# Top level Makefile, runs make in subdirectories.
#
# Copyright (C) 2013 Holger Oehm
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

all: firmware device java

firmware:
	$(MAKE) -C firmware/18f13k50 clean all

device: firmware
	$(MAKE) -C device clean all

java:
	( cd java; mvn clean install )

clean:
	$(MAKE) -C firmware clean
	$(MAKE) -C device clean
	( cd java; mvn clean )

.PHONY: all firmware device clean java
