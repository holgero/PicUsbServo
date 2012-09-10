/*
 *  Copyright (C) 2012 Holger Oehm
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

package de.holger_oehm.pic.usb.device;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

import org.apache.commons.io.IOUtils;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.IntByReference;

public interface Usblib extends Library {
    public static final int LIBUSB_SUCCESS = 0;
    public static final int LIBUSB_ERROR_IO = -1;
    public static final int LIBUSB_ERROR_INVALID_PARAM = -2;
    public static final int LIBUSB_ERROR_ACCESS = -3;
    public static final int LIBUSB_ERROR_NO_DEVICE = -4;
    public static final int LIBUSB_ERROR_NOT_FOUND = -5;
    public static final int LIBUSB_ERROR_BUSY = -6;
    public static final int LIBUSB_ERROR_TIMEOUT = -7;
    public static final int LIBUSB_ERROR_OVERFLOW = -8;
    public static final int LIBUSB_ERROR_PIPE = -9;
    public static final int LIBUSB_ERROR_INTERRUPTED = -10;
    public static final int LIBUSB_ERROR_NO_MEM = -11;
    public static final int LIBUSB_ERROR_NOT_SUPPORTED = -12;
    public static final int LIBUSB_ERROR_OTHER = -99;

    static final int PATH_MAX = 4096;

    static class NativeLoader {
        public static Usblib loadLibrary() {
            final Usblib lib;
            if ("linux".equalsIgnoreCase(System.getProperty("os.name"))) {
                lib = (Usblib) Native.loadLibrary("usb-1.0", Usblib.class);
            } else {
                final String architectureBits = System.getProperty("sun.arch.data.model");
                final File libraryFile = copyToFileSystem("libusb-1.0-win" + architectureBits + ".dll");
                lib = (Usblib) Native.loadLibrary(libraryFile.getAbsolutePath(), Usblib.class);
            }
            final int result = lib.libusb_init(null);
            if (result != 0) {
                throw new RuntimeException("failed to init libusb: " + result);
            }
            return lib;
        }

        private static File copyToFileSystem(final String libraryName) {
            final File libraryFile = new File(System.getProperty("java.io.tempdir"), "libusb-1.0.dll");
            try {
                final InputStream source = NativeLoader.class.getClassLoader().getResourceAsStream(libraryName);
                try (final FileOutputStream target = new FileOutputStream(libraryFile)) {
                    IOUtils.copy(source, target);
                } finally {
                    source.close();
                }
            } catch (final IOException e) {
                throw new RuntimeException(e);
            }
            return libraryFile;
        }
    }

    static Usblib INSTANCE = NativeLoader.loadLibrary();

    int libusb_init(Pointer ctx);

    Pointer libusb_open_device_with_vid_pid(Pointer ctx, short vendor_id, short product_id);

    int libusb_detach_kernel_driver(Pointer handle, int interfaceNumber);

    int libusb_claim_interface(Pointer handle, int interfaceNumber);

    int libusb_release_interface(Pointer handle, int interfaceNumber);

    void libusb_close(Pointer handle);

    int libusb_control_transfer(Pointer handle, byte bmRequestType, byte bRequest, short wValue, short wIndex, byte[] data,
            short wLength, int timeout);

    int libusb_bulk_transfer(Pointer handle, byte endpoint, byte[] data, int length, IntByReference transferred, int timeout);
}