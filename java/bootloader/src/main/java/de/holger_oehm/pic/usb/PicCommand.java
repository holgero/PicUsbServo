package de.holger_oehm.pic.usb;

import java.io.IOException;

abstract class PicCommand {
    abstract int run() throws IOException;
}
