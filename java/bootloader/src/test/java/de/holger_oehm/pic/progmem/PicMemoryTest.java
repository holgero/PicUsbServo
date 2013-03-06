package de.holger_oehm.pic.progmem;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.is;
import static org.junit.Assert.assertThat;

import java.util.Arrays;

import org.junit.Test;

public class PicMemoryTest {

    private final PicMemory memory = new PicMemory();

    @Test
    public void testSetZeroByteAtZero() {
        memory.setBytes(0x0000, 0x00);
        assertThat(memory.getByte(0x0000), is(0x00));
    }

    @Test
    public void testSetZeroByteAtOne() {
        memory.setBytes(0x0001, 0x00);
        assertThat(memory.getByte(0x0001), is(0x00));
    }

    @Test
    public void testSetOneByteAtZero() {
        memory.setBytes(0x0000, 0x01);
        assertThat(memory.getByte(0x0000), is(0x01));
    }

    @Test
    public void testSetOneByteAtOne() {
        memory.setBytes(0x0001, 0x01);
        assertThat(memory.getByte(0x0001), is(0x01));
    }

    @Test
    public void testSetTwoBytesWithDifferingValues() {
        memory.setBytes(0x0000, 0x00);
        memory.setBytes(0x0001, 0x01);
        assertThat(memory.getByte(0x0000), is(0x00));
        assertThat(memory.getByte(0x0001), is(0x01));
    }

    @Test
    public void testSetBytes() throws Exception {
        memory.setBytes(0x0010, 0x01, 0x82, 0x03);
        assertThat(memory.getByte(0x0010), is(0x01));
        assertThat(memory.getByte(0x0011), is(0x82));
        assertThat(memory.getByte(0x0012), is(0x03));
    }

    @Test(expected = IllegalArgumentException.class)
    public void testTooLargeValue() throws Exception {
        memory.setBytes(0x0000, 0x100);
    }

    @Test(expected = IllegalArgumentException.class)
    public void testTooSmallValue() throws Exception {
        memory.setBytes(0x0000, -1);
    }

    @Test
    public void testChunksAreEmpty() throws Exception {
        assertThat(memory.getChunkAddresses(), is(empty()));
    }

    @Test
    public void testChunksFill() throws Exception {
        memory.setBytes(0x0001, 0x00);
        assertThat(memory.getChunkAddresses(), contains(0x00));
        memory.setBytes(0x0040, 0x01);
        assertThat(memory.getChunkAddresses(), contains(0x00, 0x40));
        memory.setBytes(0x0041, 0x02);
        assertThat(memory.getChunkAddresses(), contains(0x00, 0x40));
    }

    @Test
    public void testSetBytesCrossingChunkBorder() throws Exception {
        memory.setBytes(0x3f, 0x3f, 0x40);
        assertThat(memory.getByte(0x3e), is(0xff));
        assertThat(memory.getByte(0x3f), is(0x3f));
        assertThat(memory.getByte(0x40), is(0x40));
        assertThat(memory.getByte(0x41), is(0xff));
        assertThat(memory.getChunkAddresses(), contains(0x00, 0x40));
    }

    @Test
    public void testReadUninitializedMemory() throws Exception {
        assertThat(memory.getByte(0x0), is(0xff));
        memory.setBytes(0x0000, 0x00);
        assertThat(memory.getByte(0x01), is(0xff));
    }

    @Test
    public void testSetLargeByteArray() throws Exception {
        final byte[] testData = new byte[0x80];
        Arrays.fill(testData, (byte) 0x7f);
        memory.setBytes(0x1234, testData);
        assertThat(memory.getChunkAddresses(), contains(0x1200, 0x1240, 0x1280));
        // check boundaries of set memory region: 0x1234 - 0x12b3
        assertThat(memory.getByte(0x1233), is(0xff));
        assertThat(memory.getByte(0x1234), is(0x7f));
        assertThat(memory.getByte(0x12b3), is(0x7f));
        assertThat(memory.getByte(0x12b4), is(0xff));
    }

    @Test
    public void testGetBytes() throws Exception {
        assertThat(memory.getBytes(0x00, 2), is(new byte[] { (byte) 0xff, (byte) 0xff }));
    }

    @Test
    public void testWriteFF() throws Exception {
        memory.setBytes(0x00, 0xff);
        assertThat(memory.getChunkAddresses(), is(empty()));
    }
}
