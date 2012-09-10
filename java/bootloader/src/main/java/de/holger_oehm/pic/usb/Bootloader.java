package de.holger_oehm.pic.usb;

import java.io.FileWriter;
import java.io.IOException;

import de.holger_oehm.pic.progmem.HexFileWriter;
import de.holger_oehm.pic.progmem.PicMemory;
import de.holger_oehm.pic.usb.device.ProgrammableUSBDevice;
import de.holger_oehm.pic.usb.device.USBAddress;

public class Bootloader {

    private static final USBAddress XFD_ADDRESS = new USBAddress(0x1d50, 0x6039);

    private final USBAddress usbAddress;

    public Bootloader(final String[] args) {
        if (args.length != 0) {
        }
        usbAddress = XFD_ADDRESS;
    }

    public static void main(final String[] args) throws IOException {
        final int status = new Bootloader(args).run();
        if (status != 0) {
            System.exit(status);
        }
    }

    private int run() throws IOException {
        try (final ProgrammableUSBDevice usbDevice = new ProgrammableUSBDevice(usbAddress)) {
            System.out.println("Found device at " + usbAddress + " with bootloader version " + usbDevice.readVersion());
            final PicMemory memory = new PicMemory();
            for (int address = 0x0800; address < 0x1fff; address += 16) {
                final byte[] bytes = usbDevice.readFlash(address, 16);
                memory.setBytes(address, bytes);
            }
            try (HexFileWriter writer = new HexFileWriter(memory, new FileWriter("out.hex"))) {
                writer.write();
            }
        }
        return 0;
    }

}
