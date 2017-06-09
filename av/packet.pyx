cimport libav as lib
from libc.stddef cimport ptrdiff_t
from av.utils cimport avrational_to_fraction, err_check
from cpython.buffer cimport PyObject_CheckBuffer, PyObject_GetBuffer, PyBUF_SIMPLE,PyBUF_WRITABLE, PyBUF_ND, PyBUF_STRIDES, PyBUF_INDIRECT,  PyBuffer_Release, PyBuffer_FillInfo, Py_buffer

cdef class Packet:

    """A packet of encoded data within a :class:`~av.format.Stream`.

    This may, or may not include a complete object within a stream.
    :meth:`decode` must be called to extract encoded data.

    """
    def __cinit__(self):
        with nogil:
            self.ptr = lib.av_packet_alloc()

    def __dealloc__(self):
        with nogil:
            lib.av_packet_free(&self.ptr)

    def __repr__(self):
        return '<av.%s of #%d, dts=%s, pts=%s at 0x%x>' % (
            self.__class__.__name__,
            self.stream.index,
            self.dts,
            self.pts,
            id(self),
        )

    def __getbuffer__(self, Py_buffer *view, int flags):
        if self.ptr.buf == NULL:
            raise BufferError
        cdef lib.AVBufferRef *buf = NULL
        cdef lib.AVPacket *ptr = self.ptr
        cdef lib.AVBufferRef **rptr = &ptr.buf
        cdef int err = 0
        cdef ptrdiff_t data_offset
        if flags & PyBUF_WRITABLE:
            if not lib.av_buffer_is_writable(ptr.buf):
                data_offset = ptr.data - ptr.buf.data
                with nogil:
                    err = lib.av_buffer_make_writable(rptr)
                err_check(err)
                ptr.data = ptr.buf.data + data_offset
        with nogil:
            buf = lib.av_buffer_ref(rptr[0])
        if buf == NULL:
            raise BufferError

        view.internal = <void*>buf
        err = PyBuffer_FillInfo(view, self, ptr.data, ptr.size, 0, flags)
        err_check(err)

    def __releasebuffer__(self, Py_buffer *view):
        if view == NULL:
            return
        cdef lib.AVBufferRef *ref = <lib.AVBufferRef*>view.internal
        view.internal = NULL
        if ref:
            with nogil:
                lib.av_buffer_unref(&ref)


    # Buffer protocol.
    cdef size_t _buffer_size(self):
        return self.ptr.size

    cdef void*  _buffer_ptr(self):
        return self.ptr.data

    def decode(self, count=0):
        """Decode the data in this packet into a list of Frames."""
        return self.stream.decode(self, count)

    def decode_one(self):
        """Decode the first frame from this packet.

        Returns ``None`` if there is no frame."""
        res = self.stream.decode(self, count=1)
        return res[0] if res else None

    def unref(self):
        with nogil:
            lib.av_packet_unref(self.ptr)

    def ref(self, Packet other):
        cdef lib.AVPacket * optr = other.ptr
        cdef lib.AVPacket * ptr  = self.ptr
        cdef int err = 0
        if ptr != optr:
            self.unref()
            if optr == NULL:
                return
            with nogil:
                err = lib.av_packet_ref(ptr, optr)
            err_check(err)

    # Looks circular, but isn't. Silly Cython.
    @property
    def stream(self):
        return self.stream

    @stream.setter
    def stream(self, Stream value):
        # Rescale times.
        cdef lib.AVStream *old = self.stream._stream
        cdef lib.AVStream *new = value._stream

        if old != new:
            self.unref()
        if self.ptr.pts != lib.AV_NOPTS_VALUE:
            self.ptr.pts = lib.av_rescale_q_rnd(self.ptr.pts, old.time_base, new.time_base, lib.AV_ROUND_NEAR_INF)
        if self.ptr.dts != lib.AV_NOPTS_VALUE:
            self.ptr.dts = lib.av_rescale_q_rnd(self.ptr.dts, old.time_base, new.time_base, lib.AV_ROUND_NEAR_INF)
        self.ptr.duration = lib.av_rescale_q(self.ptr.duration, old.time_base, new.time_base)

        self.stream = value
        self.ptr.stream_index = value.index

    @property
    def time_base(self):
        return avrational_to_fraction(&self._time_base)

    @time_base.setter
    def time_base(self, value):
        self._time_base.num = value.numerator
        self._time_base.den = value.denominator


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
        return None if self.ptr.dts == lib.AV_NOPTS_VALUE else self.ptr.dts
    @dts.setter
    def dts(self, v):
        if v is None:
            self.ptr.dts = lib.AV_NOPTS_VALUE
        else:
            self.ptr.dts = v

    @property
    def pos(self): return None if self.ptr.pos == -1 else self.ptr.pos

    @property
    def size(self): return self.ptr.size

    @property
    def duration(self): return None if self.ptr.duration < 0 else self.ptr.duration

    @property
    def convergence_duration(self):
        return None if self.ptr.convergence_duration ==lib.AV_NOPTS_VALUE  else self.ptr.convergence_duration

