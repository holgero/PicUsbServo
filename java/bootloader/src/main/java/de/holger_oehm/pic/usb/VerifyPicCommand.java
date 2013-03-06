package de.holger_oehm.pic.usb;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.List;

import de.holger_oehm.pic.progmem.HexFileParser;
import de.holger_oehm.pic.progmem.PicMemory;
import de.holger_oehm.pic.progmem.PicMemoryModel;
import de.holger_oehm.pic.usb.device.ProgrammableUSBDevice;
import de.holger_oehm.pic.usb.device.USBAddress;

public class VerifyPicCommand extends PicCommand {

    public VerifyPicCommand(final File file, final USBAddress usbAddress, final PicMemoryModel model) {
        super(file, usbAddress, model);
    }

    @Override
    int run() throws IOException {
        try (final ProgrammableUSBDevice usbDevice = new ProgrammableUSBDevice(getUsbAddress())) {
            System.out.println("Found device at " + getUsbAddress() + " with bootloader version " + usbDevice.readVersion());
            final PicMemory deviceMemory = new PicMemory();
            new ReadPicCommand(null, getUsbAddress(), getModel()).getMemoryImage(usbDevice, deviceMemory);
            final HexFileParser parser = new HexFileParser();
            final PicMemory fileMemory = parser.parse(getFile());
            if (compare(fileMemory, deviceMemory) == 0) {
                System.out.println("Device memory verified successfully against " + getFile().toString() + ".");
                return 0;
            }
            return 1;
        }
    }

    private int compare(final PicMemory fileMemory, final PicMemory deviceMemory) {
        final List<Integer> fileAddresses = fileMemory.getChunkAddresses();
        final List<Integer> deviceAddresses = deviceMemory.getChunkAddresses();
        if (!fileAddresses.equals(deviceAddresses)) {
            deviceAddresses.removeAll(fileAddresses);
            if (!fileAddresses.isEmpty()) {
                System.out.println("Addresses programmed in the device but not in the file: " + deviceAddresses);
            }
            fileAddresses.removeAll(deviceMemory.getChunkAddresses());
            if (!deviceAddresses.isEmpty()) {
                System.out.println("Addresses in the file but not programmed in the device: " + fileAddresses);
            }
            return -(deviceAddresses.size() + fileAddresses.size());
        }
        int diffs = 0;
        for (final int address : deviceAddresses) {
            final byte[] deviceBytes = deviceMemory.getBytes(address, 16);
            final byte[] fileBytes = fileMemory.getBytes(address, 16);
            if (!Arrays.equals(deviceBytes, fileBytes)) {
                System.out.println("Bytes at 0x" + Integer.toHexString(address) + " differ: ");
                System.out.println("  device: " + Arrays.toString(deviceBytes));
                System.out.println("    file: " + Arrays.toString(fileBytes));
                diffs++;
            }
        }
        return diffs;
    }
}
