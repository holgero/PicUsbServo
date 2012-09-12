package de.holger_oehm.pic.usb;

import java.io.File;
import java.io.IOException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;

import de.holger_oehm.pic.progmem.PicMemoryModel;
import de.holger_oehm.pic.usb.device.USBAddress;

public class CommandDispatcher {
    private static final USBAddress XFD_ADDRESS = new USBAddress(0x1d50, 0x6039);
    private static final Options OPTIONS = createOptions();

    private static Options createOptions() {
        final Options result = new Options();
        result.addOption("h", "help", false, "write this help text");
        result.addOption("v", "version", false, "print version of the bootloader and exit");
        result.addOption("p", "program", true, "program and verify the given hex file");
        result.addOption("y", "verify", true, "verify the memory content against the given hex file");
        result.addOption("r", "read", true, "write the memory content to the given hex file");
        result.addOption("d", "device", true,
                "use the given vvvv:pppp vendor id and product id to search for the programable device");
        return result;
    }

    private final CommandLine parsedArguments;

    public CommandDispatcher(final String[] args) throws ParseException {
        parsedArguments = parseArguments(args);
    }

    private void printVersion() {
        System.out.println("0.1.0-SNAPSHOT");
    }

    private void printHelp(final String header) {
        final HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp("java -jar bootloader.jar", header, OPTIONS,
                "Exactly one command (read, program, verify, help, version) is required.", true);
    }

    private CommandLine parseArguments(final String[] args) throws ParseException {
        return new PosixParser().parse(OPTIONS, args);
    }

    public int run() throws IOException {
        if (parsedArguments.hasOption('h')) {
            printHelp("");
            return 0;
        }
        if (parsedArguments.hasOption('v')) {
            printVersion();
            return 0;
        }
        final PicCommand command;
        if (parsedArguments.hasOption('r')) {
            final String fileName = parsedArguments.getOptionValue('r');
            command = new ReadPicCommand(new File(fileName), XFD_ADDRESS, PicMemoryModel.PIC18F13K50);
        } else if (parsedArguments.hasOption('p')) {
            final String fileName = parsedArguments.getOptionValue('p');
            command = new WritePicCommand(new File(fileName), XFD_ADDRESS, PicMemoryModel.PIC18F13K50);
        } else {
            printHelp("No command given.");
            return 1;
        }
        final int status = command.run();
        if (status != 0) {
            System.exit(status);
        }
        return 0;
    }

}
