cimport libav as lib


cdef class Descriptor:
    cdef object __weakref__
    cdef const lib.AVClass *ptr
    cdef object _options # Option list cache.

cdef Descriptor wrap_avclass(const lib.AVClass*)
