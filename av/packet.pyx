cimport libav as lib
from av.utils cimport avrational_to_fraction


cdef class Packet(object):

    """A packet of encoded data within a :class:`~av.format.Stream`.

    This may, or may not include a complete object within a stream.
    :meth:`decode` must be called to extract encoded data.

    """
    def __init__(self):
        with nogil:
            lib.av_init_packet(&self.struct)
            self.struct.data = NULL
            self.struct.size = 0

    def __dealloc__(self):
        with nogil: lib.av_free_packet(&self.struct)

    def __repr__(self):
        return '<av.%s of #%d, dts=%s, pts=%s at 0x%x>' % (
            self.__class__.__name__,
            self.stream.index,
            self.dts,
            self.pts,
            id(self),
        )

    # Buffer protocol.
    cdef size_t _buffer_size(self):
        return self.struct.size
    cdef void*  _buffer_ptr(self):
        return self.struct.data

    def decode(self, count=0):
        """Decode the data in this packet into a list of Frames."""
        return self.stream.decode(self, count)

    def decode_one(self):
        """Decode the first frame from this packet.

        Returns ``None`` if there is no frame."""
        res = self.stream.decode(self, count=1)
        return res[0] if res else None

    # Looks circular, but isn't. Silly Cython.
    @property
    def stream(self):
        return self.stream
    @stream.setter
    def stream(self, Stream value):
        # Rescale times.
        cdef lib.AVStream *old = self.stream._stream
        cdef lib.AVStream *new = value._stream
        if self.struct.pts != lib.AV_NOPTS_VALUE:
            self.struct.pts = lib.av_rescale_q_rnd(self.struct.pts, old.time_base, new.time_base, lib.AV_ROUND_NEAR_INF)
        if self.struct.dts != lib.AV_NOPTS_VALUE:
            self.struct.dts = lib.av_rescale_q_rnd(self.struct.dts, old.time_base, new.time_base, lib.AV_ROUND_NEAR_INF)
        self.struct.duration = lib.av_rescale_q(self.struct.duration, old.time_base, new.time_base)

        self.stream = value
        self.struct.stream_index = value.index

    @property
    def time_base(self):
        return avrational_to_fraction(&self._time_base)

    @time_base.setter
    def time_base(self, value):
        self._time_base.num = value.numerator
        self._time_base.den = value.denominator


    @property
    def pts(self):
        return None if self.struct.pts == lib.AV_NOPTS_VALUE else self.struct.pts
    @pts.setter
    def pts(self, v):
        if v is None:
            self.struct.pts = lib.AV_NOPTS_VALUE
        else:
            self.struct.pts = v

    @property
    def dts(self):
        return None if self.struct.dts == lib.AV_NOPTS_VALUE else self.struct.dts
    @dts.setter
    def dts(self, v):
        if v is None:
            self.struct.dts = lib.AV_NOPTS_VALUE
        else:
            self.struct.dts = v

    @property
    def pos(self): return None if self.struct.pos == -1 else self.struct.pos

    @property
    def size(self): return self.struct.size

    @property
    def duration(self): return None if self.struct.duration < 0 else self.struct.duration

    @property
    def convergence_duration(self):
        return None if self.struct.convergence_duration ==lib.AV_NOPTS_VALUE  else self.struct.convergence_duration

