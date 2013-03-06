package de.holger_oehm.pic.progmem;

import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.hasSize;
import static org.junit.Assert.assertThat;

import java.io.IOException;
import java.io.StringReader;

import org.junit.Test;

public class HexFileParserTest {
    final HexFileParser hexFileParser = new HexFileParser();

    @Test
    public void testReadEOF() throws IOException {
        final PicMemory memory = parse(":00000001ff");
        assertThat(hexFileParser.getWarnings(), is(empty()));
        assertThat(memory.getChunkAddresses(), is(empty()));
    }

    @Test
    public void testGotNoEOF() throws IOException {
        final PicMemory memory = parse("");
        assertThat(hexFileParser.getWarnings().get(0), is("EOF record is missing"));
        assertThat(memory.getChunkAddresses(), is(empty()));
    }

    @Test
    public void testReadTestFile() throws Exception {
        final String testData = "" + //
                ":020000040000FA\n" + // 
                ":0C0800000EEF00F0FFFFFFFF04EF04F01C\n" + // 
                ":0C081000FFFFFFFFFFFFFFFF0CEF04F0F5\n" + //
                ":020000040020DA\n" + //
                ":020000040030CA\n" + //
                ":0E000000340E3F1E008181000FC00FA00F4084\n" + //
                ":02000004003FBB\n" + //
                ":02FFFE004212AD\n" + //
                ":00000001FF\n";
        final PicMemory memory = parse(testData);
        assertThat(hexFileParser.getWarnings(), is(empty()));
        assertThat(memory.getChunkAddresses(), hasSize(3));
        assertThat(memory.getByte(0x0800), is(0x0e));
        assertThat(memory.getByte(0x0808), is(0x04));
        assertThat(memory.getByte(0x0810), is(0xff));
        assertThat(memory.getByte(0x00300000), is(0x34));
        assertThat(memory.getByte(0x0030000d), is(0x40));
        assertThat(memory.getByte(0x003ffffe), is(0x42));
        assertThat(memory.getByte(0x003fffff), is(0x12));
    }

    private PicMemory parse(final String data) throws IOException {
        return hexFileParser.parse(new StringReader(data));
    }
}
