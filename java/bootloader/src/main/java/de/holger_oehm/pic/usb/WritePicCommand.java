package de.holger_oehm.pic.usb;

import java.io.File;
import java.io.IOException;

import de.holger_oehm.pic.progmem.HexFileParser;
import de.holger_oehm.pic.progmem.PicMemory;
import de.holger_oehm.pic.progmem.PicMemoryModel;
import de.holger_oehm.pic.usb.device.ProgrammableUSBDevice;
import de.holger_oehm.pic.usb.device.USBAddress;

public class WritePicCommand extends PicCommand {

    public WritePicCommand(final File file, final USBAddress usbAddress, final PicMemoryModel model) {
        super(file, usbAddress, model);
    }

    @Override
    int run() throws IOException {
        try (final ProgrammableUSBDevice usbDevice = new ProgrammableUSBDevice(getUsbAddress())) {
            System.out.println("Found device at " + getUsbAddress() + " with bootloader version " + usbDevice.readVersion());
            final HexFileParser parser = new HexFileParser();
            final PicMemory memory = parser.parse(getFile());
            for (final int address : memory.getChunkAddresses()) {
                if (getModel().getCode().contains(address)) {
                    usbDevice.writeCodeFlash(address, memory.getBytes(address, PicMemory.CHUNK_SIZE));
                }
            }
        }
        return new VerifyPicCommand(getFile(), getUsbAddress(), getModel()).run();
    }

}
