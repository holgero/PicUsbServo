package de.holger_oehm.pic.usb;

import java.io.IOException;

import org.apache.commons.cli.ParseException;

public class Bootloader {
    public static void main(final String[] args) throws IOException, ParseException {
        final int status = new CommandDispatcher(args).run();
        System.exit(status);
    }
}
