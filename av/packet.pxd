cimport libav as lib

from av.buffer cimport Buffer
from av.stream cimport Stream


cdef class Packet:
#    cdef object __weakref__
    cdef lib.AVPacket *ptr
    cdef Stream _stream

    # Attributes copied from the stream.
    cdef lib.AVRational _time_base

    cdef size_t _buffer_size(self)
    cdef void*  _buffer_ptr(self)

    cpdef Packet copy(self)
    cpdef void ref(self, Packet other)
    cpdef void unref(self)
