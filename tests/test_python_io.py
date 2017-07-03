from __future__ import division

import math
import sys
from .common import *
if not is_py3:
    from io import StringIO
else:
    from io import BytesIO as StringIO

from .test_encode import write_rgb_rotate, assert_rgb_rotate
from av.video.stream import VideoStream




class TestPythonIO(TestCase):

    def test_reading(self):
        av.logging.set_level(av.logging.QUIET)
        with open(fate_suite('mpeg2/mpeg2_field_encoding.ts'), 'rb') as fh:
            wrapped = MethodLogger(fh)

            container = av.open(wrapped)

            self.assertEqual(container.format.name, 'mpegts')
            self.assertEqual(container.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)")
            self.assertEqual(len(container.streams), 1)
            self.assertEqual(container.size, 800000)
            self.assertEqual(container.metadata, {})

            # Make sure it did actually call "read".
            reads = wrapped._filter('read')
            self.assertTrue(reads)

    def test_basic_errors(self):
        self.assertRaises(Exception, av.open, None)
        self.assertRaises(Exception, av.open, None, 'w')

    def test_writing(self):

        av.logging.set_level(av.logging.QUIET)
        path = self.sandboxed('writing.mov')
        with open(path, 'wb') as fh:
            wrapped = MethodLogger(fh)

            output = av.open(wrapped, 'w')
            write_rgb_rotate(output)

            # Make sure it did actually write.
            writes = wrapped._filter('write')
            self.assertTrue(writes)

        # Standard assertions.
        assert_rgb_rotate(self, av.open(path))

    def test_buffer_read_write(self):
        av.logging.set_level(av.logging.QUIET)
        path = self.sandboxed('writing.mov')

        buffer_ = StringIO()
        wrapped = MethodLogger(buffer_)
        out_ = av.open(wrapped, 'w', 'mov')
        write_rgb_rotate(out_)
        out_.close()

        for lineno,line in enumerate(wrapped._log):
            print('{}:\t{}'.format(lineno,line))
        # Make sure it did actually write.
        writes = wrapped._filter('write')
        self.assertTrue(writes)

        self.assertTrue(buffer_.tell())

        # Standard assertions.
        buffer_.seek(0)
        assert_rgb_rotate(self, av.open(buffer_))
