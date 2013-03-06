/*  
 *  Copyright (C) 2012 Holger Oehm
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

package de.holger_oehm.pic.usb.leds;

import java.io.IOException;

import de.holger_oehm.pic.usb.device.USBAddress;
import de.holger_oehm.pic.usb.device.USBDevice;

public class TestUSBLeds {
    private static final USBAddress USBLEDS = new USBAddress(0x1d50, 0x6039);

    public static void main(final String[] args) throws InterruptedException, IOException {
        try (final USBLedDevice leds = new USBLedDevice(new USBDevice(USBLEDS))) {
            for (int i = 0; i < 3; i++) {
                leds.red();
                Thread.sleep(100L);
                leds.yellow();
                Thread.sleep(100L);
                leds.green();
                Thread.sleep(100L);
                leds.blue();
                Thread.sleep(100L);
                leds.white();
                Thread.sleep(100L);
                leds.magenta();
                Thread.sleep(100L);
                leds.cyan();
                Thread.sleep(100L);
                leds.off();
                Thread.sleep(200L);
            }
        }
    }
}
