package de.holger_oehm.pic.progmem;

import static org.hamcrest.CoreMatchers.is;
import static org.junit.Assert.assertThat;

import java.io.File;
import java.io.FileReader;
import java.io.LineNumberReader;

import org.junit.Test;

public class HexFileReadWriteTest {

    @Test
    public void testReadAndWriteTestFile() throws Exception {
        final String sourcePath = "src/test/resources/example.hex";
        final PicMemory memory = new HexFileParser().parse(new File(sourcePath));
        final String targetPath = "example_out.hex";
        try (final HexFileWriter writer = new HexFileWriter(memory, new File(targetPath))) {
            writer.write();
        }
        try (final LineNumberReader sourceReader = new LineNumberReader(new FileReader(sourcePath));
                LineNumberReader targetReader = new LineNumberReader(new FileReader(targetPath))) {
            do {
                final String sourceLine = sourceReader.readLine();
                assertThat(sourceLine, is(targetReader.readLine()));
                if (sourceLine == null) {
                    break;
                }
            } while (true);
        }
    }
}
