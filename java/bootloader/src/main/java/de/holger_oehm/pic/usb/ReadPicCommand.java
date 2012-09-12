package de.holger_oehm.pic.usb;

import static java.lang.Math.min;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

import de.holger_oehm.pic.progmem.HexFileWriter;
import de.holger_oehm.pic.progmem.PicMemory;
import de.holger_oehm.pic.progmem.PicMemoryModel;
import de.holger_oehm.pic.progmem.PicMemoryModel.Range;
import de.holger_oehm.pic.usb.device.ProgrammableUSBDevice;
import de.holger_oehm.pic.usb.device.USBAddress;

public class ReadPicCommand extends PicCommand {
    private static final int LINE_LEN = 16;

    private final PicMemory memory = new PicMemory();
    private final USBAddress usbAddress;
    private final PicMemoryModel model;
    private final File file;

    public ReadPicCommand(final File file, final USBAddress usbAddress, final PicMemoryModel model) {
        this.file = file;
        this.usbAddress = usbAddress;
        this.model = model;
    }

    @Override
    int run() throws IOException {
        try (final ProgrammableUSBDevice usbDevice = new ProgrammableUSBDevice(usbAddress)) {
            System.out.println("Found device at " + usbAddress + " with bootloader version " + usbDevice.readVersion());
            getProgramMemory(usbDevice, model.getCode());
            getConfigMemory(usbDevice, model.getConfig());
            try (HexFileWriter writer = new HexFileWriter(memory, new FileWriter(file))) {
                writer.write();
            }
        }
        return 0;
    }

    private interface ByteReader {
        byte[] readBytes(int address, int len);
    }

    private void getProgramMemory(final ProgrammableUSBDevice usbDevice, final Range range) {
        retrieveRange(new ByteReader() {
            @Override
            public byte[] readBytes(final int address, final int len) {
                return usbDevice.readFlash(address, len);
            }
        }, range);
    }

    private void getConfigMemory(final ProgrammableUSBDevice usbDevice, final Range range) {
        retrieveRange(new ByteReader() {
            @Override
            public byte[] readBytes(final int address, final int len) {
                return usbDevice.readConfig(address, LINE_LEN);
            }
        }, range);
    }

    private void retrieveRange(final ByteReader byteReader, final Range range) {
        for (int address = range.getStart(); address <= range.getEnd(); address += LINE_LEN) {
            final int remaining = range.getEnd() - address + 1;
            final int len = min(LINE_LEN, remaining);
            final byte[] bytes = byteReader.readBytes(address, len);
            memory.setBytes(address, bytes);
        }
    }
}
