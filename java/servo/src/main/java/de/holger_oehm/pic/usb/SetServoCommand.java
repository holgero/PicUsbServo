/*
 *  Copyright (C) 2013 Holger Oehm
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

package de.holger_oehm.pic.usb;

import java.io.IOException;

import de.holger_oehm.pic.usb.device.ServoUSBDevice;
import de.holger_oehm.pic.usb.device.USBAddress;

public class SetServoCommand extends PicCommand {

    private final byte[] values;

    public SetServoCommand(final USBAddress usbAddress, final byte[] values) {
        super(usbAddress);
        if (values.length != 5) {
            throw new IllegalArgumentException("set servo command needs exactly 5 values");
        }
        this.values = values;
    }

    @Override
    int run() throws IOException {
        try (final ServoUSBDevice usbDevice = new ServoUSBDevice(getUsbAddress())) {
            System.out.println("Found device at " + getUsbAddress());
            usbDevice.setServos(values);
        }
        return 0;
    }

}
