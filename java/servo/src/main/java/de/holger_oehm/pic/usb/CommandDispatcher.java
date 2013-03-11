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

package de.holger_oehm.pic.usb;

import java.io.IOException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;

import de.holger_oehm.pic.usb.device.USBAddress;

public class CommandDispatcher {
    private static final USBAddress SERVO_ADDRESS = new USBAddress(0x04d8, 0xf79b);
    private static final Options OPTIONS = createOptions();

    private static Options createOptions() {
        final Options result = new Options();
        result.addOption("h", "help", false, "write this help text");
        result.addOption("v", "version", false, "print version of the bootloader and exit");
        result.addOption("r", "readservo", false, "read the servo positions");
        result.addOption("s", "setservo", true, "set the servo positions s1,s2,s3,s4,s5 (0-255)");
        result.addOption("f", "flash", false, "prepare the device for firmware upload");
        result.addOption(
                "d",
                "device",
                true,
                "use the given vvvv:pppp vendor id and product id to search for the programable device (specify both vid and pid in hexadecimal, without a leading '0x')");
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
        formatter.printHelp("java -jar servoctl.jar", header, OPTIONS, "", true);
    }

    private CommandLine parseArguments(final String[] args) throws ParseException {
        return new PosixParser().parse(OPTIONS, args);
    }

    public int run() throws IOException {
        USBAddress usbAddress = SERVO_ADDRESS;
        if (parsedArguments.hasOption('h')) {
            printHelp("");
            return 0;
        }
        if (parsedArguments.hasOption('v')) {
            printVersion();
            return 0;
        }
        if (parsedArguments.hasOption('d')) {
            final String[] vidPid = parsedArguments.getOptionValue('d').split(":");
            if (vidPid.length != 2) {
                printHelp("Wrong format for USB address " + parsedArguments.getOptionValue('d') + ", expected VID:PID");
                return 1;
            }
            try {
                final int vid = Integer.parseInt(vidPid[0], 16);
                final int pid = Integer.parseInt(vidPid[1], 16);
                usbAddress = new USBAddress(vid, pid);
            } catch (final NumberFormatException e) {
                printHelp("Wrong format for USB address " + parsedArguments.getOptionValue('d') + ", "
                        + e.getClass().getSimpleName() + ": " + e.getMessage());
                return 1;
            }
        }
        final PicCommand command;
        if (parsedArguments.hasOption('s')) {
            final byte[] values = parseByteValues(parsedArguments.getOptionValue('s'));
            command = new SetServoCommand(usbAddress, values);
        } else if (parsedArguments.hasOption('r')) {
            command = new GetServoCommand(usbAddress);
        } else if (parsedArguments.hasOption('f')) {
            command = new PrepareFlashCommand(usbAddress);
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

    private byte[] parseByteValues(final String optionValues) {
        final String[] values = optionValues.split(",", 5);
        final byte[] result = new byte[values.length];
        for (int i = 0; i < values.length; i++) {
            result[i] = toByte(values[i], optionValues);
        }
        return result;
    }

    private byte toByte(final String value, final String optionValues) {
        final int intValue = Integer.parseInt(value);
        if ((intValue < 0) || (intValue > 255)) {
            throw new IllegalArgumentException("Value not in range (0-255): " + intValue + " in values '" + optionValues + "'");
        }
        return (byte) intValue;
    }

}
