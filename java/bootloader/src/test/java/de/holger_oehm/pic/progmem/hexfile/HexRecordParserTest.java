package de.holger_oehm.pic.progmem.hexfile;

import static org.hamcrest.CoreMatchers.is;
import static org.junit.Assert.assertThat;

import org.junit.Test;

import de.holger_oehm.pic.progmem.hexfile.DataRecord;
import de.holger_oehm.pic.progmem.hexfile.EOFRecord;
import de.holger_oehm.pic.progmem.hexfile.HexRecordParser;
import de.holger_oehm.pic.progmem.hexfile.LinearAddressRecord;
import de.holger_oehm.pic.progmem.hexfile.LinearStartRecord;
import de.holger_oehm.pic.progmem.hexfile.RecordType;
import de.holger_oehm.pic.progmem.hexfile.SegmentRecord;
import de.holger_oehm.pic.progmem.hexfile.SegmentStartRecord;


public class HexRecordParserTest {
    @Test
    public void testParseEOFRecord() throws Exception {
        final EOFRecord record = HexRecordParser.parse(":00000001ff");
        assertThat(record.getType(), is(RecordType.EOF));
    }

    @Test
    public void testParseEmptyDataRecord() throws Exception {
        final DataRecord record = HexRecordParser.parse(":0000000000");
        assertThat(record.getType(), is(RecordType.DATA));
        assertThat(record.getLength(), is(0));
        assertThat(record.getAddress(), is(0));
        assertThat(record.getBytes(), is(new byte[0]));
    }

    @Test
    public void testParseSegmentAddressRecord() throws Exception {
        final SegmentRecord record = HexRecordParser.parse(":020000021234B6");
        assertThat(record.getType(), is(RecordType.SEG_ADDR));
        assertThat(record.getSegment(), is(0x1234));
        assertThat(record.getUpperAddress(), is(0x00123400));
    }

    @Test(expected = IllegalArgumentException.class)
    public void testParseSegmentAddressWithWrongLength() throws Exception {
        HexRecordParser.parse(":03000002123400B5");
    }

    @Test(expected = IllegalArgumentException.class)
    public void testParseSegmentAddressWithWrongAddress() throws Exception {
        HexRecordParser.parse(":02010002123400B5");
    }

    @Test
    public void testParseStartSegmentRecord() throws Exception {
        final SegmentStartRecord record = HexRecordParser.parse(":0400000301020304ef");
        assertThat(record.getType(), is(RecordType.SEG_START));
        assertThat(record.getSegment(), is(0x0102));
        assertThat(record.getOffset(), is(0x0304));
    }

    @Test
    public void testParseLinearAddressRecord() throws Exception {
        final LinearAddressRecord record = HexRecordParser.parse(":02000004000Af0");
        assertThat(record.getType(), is(RecordType.LIN_ADDR));
        assertThat(record.getUpperAddress(), is(0x000a0000));
    }

    @Test
    public void testParseStartAddressRecord() throws Exception {
        final LinearStartRecord record = HexRecordParser.parse(":040000051020304057");
        assertThat(record.getType(), is(RecordType.LIN_START));
        assertThat(record.getLinearAddress(), is(0x10203040));
    }

    @Test
    public void testParseOneByteDataRecord() throws Exception {
        final DataRecord record = HexRecordParser.parse(":0100010001fd");
        assertThat(record.getType(), is(RecordType.DATA));
        assertThat(record.getLength(), is(1));
        assertThat(record.getAddress(), is(1));
        assertThat(record.getBytes(), is(new byte[] { 1 }));
    }

    @Test
    public void testParseTenByteDataRecord() throws Exception {
        final DataRecord record = HexRecordParser.parse(":0a66a000000000000000000000f1ff");
        assertThat(record.getType(), is(RecordType.DATA));
        assertThat(record.getLength(), is(10));
        assertThat(record.getAddress(), is(0x066a0));
        assertThat(record.getBytes()[8], is((byte) 0x00));
        assertThat(record.getBytes()[9], is((byte) 0xf1));
    }

    @Test(expected = IllegalArgumentException.class)
    public void testRecordChecksum() throws Exception {
        HexRecordParser.parse(":0100000001ff");
    }

    @Test(expected = IllegalArgumentException.class)
    public void testIllegalRecordFormat() throws Exception {
        HexRecordParser.parse("+0100000001fe");
    }

    @Test(expected = IllegalArgumentException.class)
    public void testOddPayloadBytes() throws Exception {
        HexRecordParser.parse(":010000001fe");
    }

    @Test(expected = IllegalArgumentException.class)
    public void testIllegalRecordCharacter() throws Exception {
        try {
            HexRecordParser.parse(":01x0000001fe");
        } catch (final NumberFormatException e) {
        }
    }

}
