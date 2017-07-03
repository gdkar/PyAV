cimport libav as lib

from av.bytesource cimport bytesource
from av.utils cimport avrational_to_fraction, to_avrational, err_check


cdef class Packet(Buffer):

    """A packet of encoded data within a :class:`~av.format.Stream`.

    This may, or may not include a complete object within a stream.
    :meth:`decode` must be called to extract encoded data.

    """

    def __cinit__(self, input=None):
        with nogil:
            self._ptr = lib.av_packet_alloc()

    def __init__(self, input=None):

        cdef size_t size = 0
        cdef ByteSource source = None

        if input is None:
            return

        if isinstance(input, (int, long)):
            size = input
        else:
            source = bytesource(input)
            size = source.length

        if size:
            err_check(lib.av_new_packet(self._ptr, size))

        if source is not None:
            self.update_buffer(source)
            # TODO: Hold onto the source, and copy its pointer
            # instead of its data.
            #self.source = source

    def __dealloc__(self):
        with nogil:
            lib.av_packet_free(&self._ptr)

    def __repr__(self):
        return '<av.%s of #%d, dts=%s, pts=%s; %s bytes at 0x%x>' % (
            self.__class__.__name__,
            self._stream.index if self._stream else 0,
            self.dts,
            self.pts,
            self._ptr.size,
            id(self),
        )

    # Buffer protocol.
    cdef size_t _buffer_size(self):
        return self._ptr.size
    cdef void*  _buffer_ptr(self):
        return self._ptr.data
    #cdef bint _buffer_writable(self):
    #    return self.source is None

    def copy(self):
        cdef Packet copy = Packet()
        with nogil:
            lib.av_packet_ref(copy._ptr, self._ptr)
        # copy._ptr.size = self._ptr.size
        # copy._ptr.data = NULL
        return copy

    cdef _rebase_time(self, lib.AVRational dst):

        if not dst.num:
            raise ValueError('Cannot rebase to zero time.')

        if not self._time_base.num:
            self._time_base = dst
            return

        if self._time_base.num == dst.num and self._time_base.den == dst.den:
            return

        # TODO: Isn't there a function to do this?

        if self._ptr.pts != lib.AV_NOPTS_VALUE:
            self._ptr.pts = lib.av_rescale_q(
                self._ptr.pts,
                self._time_base, dst
            )
        if self._ptr.dts != lib.AV_NOPTS_VALUE:
            self._ptr.dts = lib.av_rescale_q(
                self._ptr.dts,
                self._time_base, dst
            )
        if self._ptr.duration > 0:
            self._ptr.duration = lib.av_rescale_q(
                self._ptr.duration,
                self._time_base, dst
            )

        self._time_base = dst

    def decode(self, count=0):
        """Decode the data in this packet into a list of Frames."""
        return self._stream.decode(self, count)

    def decode_one(self):
        """Decode the first frame from this packet.

        Returns ``None`` if there is no frame."""
        res = self._stream.decode(self, count=1)
        return res[0] if res else None

    property stream_index:
        def __get__(self):
            return self._ptr.stream_index

    property stream:
        def __get__(self):
            return self._stream
        def __set__(self, Stream stream):
            self._stream = stream
            #self._rebase_time(stream._stream.time_base)
            self._ptr.stream_index = stream._stream.index

    property time_base:
        def __get__(self):
            return avrational_to_fraction(&self._time_base)
        def __set__(self, value):
            to_avrational(value, &self._time_base)

    property pts:
        def __get__(self):
            if self._ptr.pts != lib.AV_NOPTS_VALUE:
                return self._ptr.pts
        def __set__(self, v):
            if v is None:
                self._ptr.pts = lib.AV_NOPTS_VALUE
            else:
                self._ptr.pts = v

    property dts:
        def __get__(self):
            if self._ptr.dts != lib.AV_NOPTS_VALUE:
                return self._ptr.dts
        def __set__(self, v):
            if v is None:
                self._ptr.dts = lib.AV_NOPTS_VALUE
            else:
                self._ptr.dts = v

    property pos:
        def __get__(self): return None if self._ptr.pos == -1 else self._ptr.pos
    property size:
        def __get__(self): return self._ptr.size
    property duration:
        def __get__(self): return None if self._ptr.duration == lib.AV_NOPTS_VALUE else self._ptr.duration

    property is_keyframe:
        def __get__(self): return bool(self._ptr.flags & lib.AV_PKT_FLAG_KEY)

    property is_corrupt:
        def __get__(self): return bool(self._ptr.flags & lib.AV_PKT_FLAG_CORRUPT)
