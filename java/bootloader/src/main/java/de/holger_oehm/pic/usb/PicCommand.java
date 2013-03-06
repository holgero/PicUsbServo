package de.holger_oehm.pic.usb;

import java.io.File;
import java.io.IOException;

import de.holger_oehm.pic.progmem.PicMemoryModel;
import de.holger_oehm.pic.usb.device.USBAddress;

abstract class PicCommand {
    private final File file;
    private final USBAddress usbAddress;
    private final PicMemoryModel model;

    public PicCommand(final File file, final USBAddress usbAddress, final PicMemoryModel model) {
        this.file = file;
        this.usbAddress = usbAddress;
        this.model = model;
    }

    abstract int run() throws IOException;

    USBAddress getUsbAddress() {
        return usbAddress;
    }

    File getFile() {
        return file;
    }

    PicMemoryModel getModel() {
        return model;
    }
}
