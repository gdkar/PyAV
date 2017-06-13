from libc.stdint cimport uint64_t

cimport libav as lib


cdef class Codec:
    cdef object __weakref__
    cdef lib.AVCodec *ptr
    cdef lib.AVCodecDescriptor *desc
    cdef readonly bint is_encoder


cdef class CodecContext:
    cdef object __weakref__
    cdef lib.AVCodecContext *ptr
    cdef readonly Codec
