package de.holger_oehm.pic.usb;

import java.io.File;
import java.io.IOException;

import de.holger_oehm.pic.progmem.HexFileParser;
import de.holger_oehm.pic.progmem.PicMemory;
import de.holger_oehm.pic.progmem.PicMemoryModel;
import de.holger_oehm.pic.usb.device.ProgrammableUSBDevice;
import de.holger_oehm.pic.usb.device.USBAddress;

public class WritePicCommand extends PicCommand {

    private final File file;
    private final USBAddress usbAddress;
    private final PicMemoryModel model;

    public WritePicCommand(final File file, final USBAddress usbAddress, final PicMemoryModel model) {
        this.file = file;
        this.usbAddress = usbAddress;
        this.model = model;
    }

    @Override
    int run() throws IOException {
        try (final ProgrammableUSBDevice usbDevice = new ProgrammableUSBDevice(usbAddress)) {
            System.out.println("Found device at " + usbAddress + " with bootloader version " + usbDevice.readVersion());
            final HexFileParser parser = new HexFileParser();
            final PicMemory memory = parser.parse(file);
            for (final int address : memory.getChunkAddresses()) {
                if (model.getCode().contains(address)) {
                    usbDevice.writeCodeFlash(address, memory.getBytes(address, PicMemory.CHUNK_SIZE));
                }
            }
        }
        return 0;
    }

}
