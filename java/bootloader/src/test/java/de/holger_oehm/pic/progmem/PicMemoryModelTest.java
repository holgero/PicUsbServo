package de.holger_oehm.pic.progmem;

import static org.hamcrest.CoreMatchers.is;
import static org.junit.Assert.assertThat;

import org.junit.Test;

public class PicMemoryModelTest {

    @Test
    public void test0to0Contains0() {
        final PicMemoryModel.Range range = new PicMemoryModel.Range(0, 0);
        assertThat(range.contains(0), is(true));
        assertThat(range.contains(1), is(false));
    }

    @Test
    public void test2to3ContainsNot1() {
        final PicMemoryModel.Range range = new PicMemoryModel.Range(2, 3);
        assertThat(range.contains(2), is(true));
        assertThat(range.contains(1), is(false));
    }

}
