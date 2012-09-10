package de.holger_oehm.pic.progmem;

import static org.hamcrest.CoreMatchers.is;
import static org.junit.Assert.assertThat;

import java.io.StringWriter;

import org.junit.Test;

public class HexFileWriterTest {

    private final StringWriter result = new StringWriter();
    private final PicMemory memory = new PicMemory();

    @Test
    public void testEmptyFile() {
        assertThat(writeToHex(), is(":00000001ff\n"));
    }

    @Test
    public void testZeroByteAt0() throws Exception {
        memory.setBytes(0x0000, 0x00);
        assertThat(writeToHex(), is(":020000040000fa\n:0200000000ffff\n:00000001ff\n"));
    }

    @Test
    public void testZeroByteAt64() throws Exception {
        memory.setBytes(0x0040, 0x00);
        assertThat(writeToHex(), is(":020000040000fa\n:0200400000ffbf\n:00000001ff\n"));
    }

    @Test
    public void testOneByte() throws Exception {
        memory.setBytes(0x0000, 0x01);
        assertThat(writeToHex(), is(":020000040000fa\n:0200000001fffe\n:00000001ff\n"));
    }

    @Test
    public void testTwoBytes() throws Exception {
        memory.setBytes(0x0000, 0x01, 0x02);
        assertThat(writeToHex(), is(":020000040000fa\n:020000000102fb\n:00000001ff\n"));
    }

    @Test
    public void testSixteenBytes() throws Exception {
        final byte[] testData = new byte[16];
        memory.setBytes(0x0000, testData);
        assertThat(writeToHex(), is(":020000040000fa\n" + ":1000000000000000000000000000000000000000f0\n" + ":00000001ff\n"));
    }

    @Test
    public void testSeventeenBytes() throws Exception {
        final byte[] testData = new byte[17];
        memory.setBytes(0x0000, testData);
        assertThat(writeToHex(), is(":020000040000fa\n" + ":1000000000000000000000000000000000000000f0\n" + ":0200100000ffef\n"
                + ":00000001ff\n"));
    }

    @Test
    public void testLineWithFFByte() throws Exception {
        final byte[] testData = new byte[] { 0x01, (byte) 0xff, 0x02 };
        memory.setBytes(0x0000, testData);
        assertThat(writeToHex(), is(":020000040000fa\n:0400000001ff02fffb\n:00000001ff\n"));
    }

    @Test
    public void testBytesInMultipleChunks() throws Exception {
        final byte[] testData = new byte[] { 0x01, (byte) 0xff, 0x02 };
        memory.setBytes(0x0040, testData);
        memory.setBytes(0x0125, testData);
        assertThat(writeToHex(), is(":020000040000fa\n:0400400001ff02ffbb\n:08012000ffffffffff01ff02da\n:00000001ff\n"));
    }

    @Test
    public void testBytesOverAddressBoundary() throws Exception {
        final byte[] testData = new byte[0x80];
        for (int i = 0; i < 16; i++) {
            testData[i] = (byte) i;
        }
        memory.setBytes(0xffd0, testData);
        assertThat(writeToHex(), is(":020000040000fa\n" //
                + ":10ffd000000102030405060708090a0b0c0d0e0fa9\n"
                + ":10ffe0000000000000000000000000000000000011\n"
                + ":10fff0000000000000000000000000000000000001\n"
                + ":020000040001f9\n"
                + ":1000000000000000000000000000000000000000f0\n"
                + ":1000100000000000000000000000000000000000e0\n"
                + ":1000200000000000000000000000000000000000d0\n"
                + ":1000300000000000000000000000000000000000c0\n"
                + ":1000400000000000000000000000000000000000b0\n" + ":00000001ff\n"));
    }

    private String writeToHex() {
        new HexFileWriter(memory, result).write();
        return result.toString();
    }

}
