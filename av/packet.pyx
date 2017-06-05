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
            self.ptr = lib.av_packet_alloc()

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
        cdef lib.AVPacket *ptr = self.ptr
        cdef int err = 0
        if size:
            with nogil:
                lib.av_packet_unref(self.ptr)
                err = lib.av_grow_packet(self.ptr,size)
            err_check(err)

        if source is not None:
            self.update_buffer(source)
            # TODO: Hold onto the source, and copy its pointer
            # instead of its data.
            #self.source = source

    def __dealloc__(self):
        with nogil:
            lib.av_packet_free(&self.ptr)

    def __repr__(self):
        return '<av.%s of #%d, dts=%s, pts=%s; %s bytes at 0x%x>' % (
            self.__class__.__name__,
            self._stream.index if self._stream else 0,
            self.dts,
            self.pts,
            self.ptr.size,
            id(self),
        )

    # Buffer protocol.
    cdef size_t _buffer_size(self):
        return self.ptr.size

    cdef void*  _buffer_ptr(self):
        return self.ptr.data
    #cdef bint _buffer_writable(self):
    #    return self.source is None

    def unref(self):
        with nogil:
            lib.av_packet_unref(self.ptr)

    def ref(self, Packet other):
        cdef int err
        cdef lib.AVPacket *src
        cdef lib.AVPacket *dst
        with nogil:
            lib.av_packet_unref(self.ptr)
        if other is not None:
            src = other.ptr
            dst = self.ptr
            with nogil:
                err = lib.av_packet_ref(dst, src)
            err_check(err)

    def copy(self):
        cdef Packet copy = Packet()
        with nogil:
            lib.av_packet_ref(copy.ptr,self.ptr)
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

        if self.ptr.pts != lib.AV_NOPTS_VALUE:
            self.ptr.pts = lib.av_rescale_q(
                self.ptr.pts,
                self._time_base, dst
            )
        if self.ptr.dts != lib.AV_NOPTS_VALUE:
            self.ptr.dts = lib.av_rescale_q(
                self.ptr.dts,
                self._time_base, dst
            )
        if self.ptr.duration > 0:
            self.ptr.duration = lib.av_rescale_q(
                self.ptr.duration,
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

    @property
    def stream_index(self):
        return self.ptr.stream_index

    @property
    def stream(self):
        return self._stream

    @stream.setter
    def stream(self, Stream stream):
        self._stream = stream
        #self._rebase_time(stream._stream.time_base)
        self.ptr.stream_index = stream._stream.index

    @property
    def time_base(self):
        return avrational_to_fraction(&self._time_base)

    @time_base.setter
    def time_base(self, value):
        to_avrational(value, &self._time_base)

    @property
    def pts(self):
        if self.ptr.pts != lib.AV_NOPTS_VALUE:
            return self.ptr.pts
    @pts.setter
    def pts(self, v):
        if v is None:
            self.ptr.pts = lib.AV_NOPTS_VALUE
        else:
            self.ptr.pts = v

    @property
    def dts(self):
        if self.ptr.dts != lib.AV_NOPTS_VALUE:
            return self.ptr.dts

    @dts.setter
    def dts(self, v):
        if v is None:
            self.ptr.dts = lib.AV_NOPTS_VALUE
        else:
            self.ptr.dts = v

    @property
    def pos(self):
        return None if self.ptr.pos == -1 else self.ptr.pos

    @property
    def size(self):
        return self.ptr.size

    @property
    def duration(self):
        return None if self.ptr.duration == lib.AV_NOPTS_VALUE else self.ptr.duration

    @property
    def is_keyframe(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_KEY)

    @property
    def is_corrupt(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_CORRUPT)
