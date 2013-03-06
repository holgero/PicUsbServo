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

package de.holger_oehm.pic.usb.device;

import java.util.Arrays;

import com.sun.jna.Pointer;
import com.sun.jna.ptr.IntByReference;

public class ProgrammableUSBDevice implements SimpleUSBDevice {

    private final USBAddress deviceAddress;
    private Pointer handle;

    public ProgrammableUSBDevice(final USBAddress address) {
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
    private static final byte HID_SET_REPORT = 0x09;

    private static final byte EP1OUT = (byte) 0x01;
    private static final byte EP1IN = (byte) 0x81;
    private static final byte REQUEST_VERSION = 0;
    private static final byte READ_FLASH = 1;
    private static final byte WRITE_FLASH = 2;
    private static final byte ERASE_FLASH = 3;
    private static final byte READ_CONFIG = 6;

    public String readVersion() {
        sendNoArgCommand(REQUEST_VERSION, 0, 0);
        final byte[] answer = receiveAnswer();
        return String.format("%d.%d", answer[3], answer[2]);
    }

    public byte[] readFlash(final int address, final int len) {
        if (len > 59) {
            throw new IllegalArgumentException("maximum len is 59: " + len);
        }
        sendNoArgCommand(READ_FLASH, len, address);
        final byte[] answer = receiveAnswer();
        return Arrays.copyOfRange(answer, 5, answer.length);
    }

    public void writeCodeFlash(final int address, final byte[] bytes) {
        if (bytes.length != 64) {
            throw new IllegalArgumentException("Need exactly 64 bytes for a write, but got: " + bytes.length);
        }
        if ((address & 0x3f) != 0) {
            throw new IllegalArgumentException("Address to write must be aligned to 64 byte boundary: "
                    + String.format("%04x", address));
        }
        sendNoArgCommand(ERASE_FLASH, 1, address);
        final byte[] answer = receiveAnswer();
        if (!Arrays.equals(answer, new byte[] { ERASE_FLASH })) {
            throw new USBDeviceException("Unexpected answer for erase_flash command: " + Arrays.toString(answer));
        }
        for (int i = 0; i < 4; i++) {
            writeCodeBlock(address, bytes, 16 * i);
        }
    }

    private void writeCodeBlock(final int address, final byte[] bytes, final int blockOffset) {
        final int blockAddress = address + blockOffset;
        final byte[] data = new byte[21];
        data[0] = WRITE_FLASH;
        data[1] = 16;
        data[2] = (byte) blockAddress;
        data[3] = (byte) (blockAddress >> 8);
        data[4] = (byte) (blockAddress >> 16);
        System.arraycopy(bytes, blockOffset, data, 5, 16);
        //        System.out.println(Arrays.toString(data));
        send(data);
        final byte[] answer = receiveAnswer();
        if (!Arrays.equals(answer, new byte[] { WRITE_FLASH })) {
            throw new USBDeviceException("Unexpected answer for write_flash command: " + Arrays.toString(answer));
        }
    }

    public byte[] readConfig(final int address, final int len) {
        if (len > 59) {
            throw new IllegalArgumentException("maximum len is 59: " + len);
        }
        sendNoArgCommand(READ_CONFIG, len, address);
        final byte[] answer = receiveAnswer();
        return Arrays.copyOfRange(answer, 5, answer.length);
    }

    private void sendNoArgCommand(final byte command, final int len, final int address) {
        send(new byte[] { command, (byte) len, (byte) address, (byte) (address >> 8), (byte) (address >> 16), });
    }

    private void send(final byte[] data) {
        final IntByReference transferred = new IntByReference();
        final int status = Usblib.INSTANCE.libusb_bulk_transfer(handle, EP1OUT, data, data.length, transferred, 1000);
        if (status != Usblib.LIBUSB_SUCCESS) {
            throw new USBDeviceException("bulk write failed: " + status);
        }
        if (transferred.getValue() != data.length) {
            throw new USBDeviceException("short bulk write: " + transferred.getValue());
        }
    }

    private byte[] receiveAnswer() {
        final byte[] data = new byte[64];
        final IntByReference transferred_p = new IntByReference();
        final int status = Usblib.INSTANCE.libusb_bulk_transfer(handle, EP1IN, data, data.length, transferred_p, 1000);
        if (status != Usblib.LIBUSB_SUCCESS) {
            throw new USBDeviceException("bulk read failed: " + status);
        }
        final int transferred = transferred_p.getValue();
        if (transferred == 0) {
            throw new USBDeviceException("bulk read return zero byte answer");
        }
        return Arrays.copyOf(data, transferred);
    }

    @Override
    public void setReport(final short reportNumber, final byte[] report) {
        final byte requesttype = USB_TYPE_CLASS | USB_RECIP_INTERFACE;
        final short wValue = 0;
        Usblib.INSTANCE.libusb_control_transfer(handle, requesttype, HID_SET_REPORT, wValue, reportNumber, report,
                (short) report.length, 100);
    }
}
