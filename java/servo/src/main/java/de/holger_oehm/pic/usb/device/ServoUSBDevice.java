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

package de.holger_oehm.pic.usb.device;

import com.sun.jna.Pointer;

public class ServoUSBDevice implements SimpleUSBDevice {
    private final USBAddress deviceAddress;
    private final byte[] reportData = new byte[8];
    private Pointer handle;

    public ServoUSBDevice(final USBAddress address) {
        deviceAddress = address;
        open();
    }

    private void open() {
        handle = Usblib.INSTANCE.libusb_open_device_with_vid_pid(null, deviceAddress.getVendorId(),
                deviceAddress.getProductId());
        if (handle == null) {
            throw new USBDeviceException.USBDeviceNotFoundException("no device with address " + deviceAddress + " found.");
        }
        Usblib.INSTANCE.libusb_detach_kernel_driver(handle, 0);
        Usblib.INSTANCE.libusb_claim_interface(handle, 0);
    }

    @Override
    public void close() {
        final Pointer deviceHandle = handle;
        handle = null;
        Usblib.INSTANCE.libusb_release_interface(deviceHandle, 0);
        Usblib.INSTANCE.libusb_close(deviceHandle);
    }

    private static final byte USB_TYPE_CLASS = (0x01 << 5);
    private static final byte USB_RECIP_INTERFACE = 0x01;
    private static final byte HID_GET_REPORT = 0x01;
    private static final byte HID_SET_REPORT = 0x09;
    private static final byte USB_ENDPOINT_IN = (byte) 0x80;

    @Override
    public void setReport(final short reportNumber, final byte[] report) {
        final byte requesttype = USB_TYPE_CLASS | USB_RECIP_INTERFACE;
        final short wValue = 0;
        Usblib.INSTANCE.libusb_control_transfer(handle, requesttype, HID_SET_REPORT, wValue, reportNumber, report,
                (short) report.length, 100);
    }

    public void flash() {
        reportData[7] = 0x042;
        setReport((short) 0, reportData);
    }

    public byte[] getServos() {
        getReport((short) 0, reportData);
        final byte[] result = new byte[5];
        System.arraycopy(reportData, 0, result, 0, 5);
        return result;
    }

    private void getReport(final short reportNumber, final byte[] report) {
        final byte requesttype = USB_ENDPOINT_IN | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
        Usblib.INSTANCE.libusb_control_transfer(handle, requesttype, HID_GET_REPORT, (short) 0, reportNumber, report,
                (short) report.length, 1000);
    }

    public void setServos(final byte[] values) {
        System.arraycopy(values, 0, reportData, 0, 5);
        reportData[7] = 0x01;
        setReport((short) 0, reportData);
    }
}
