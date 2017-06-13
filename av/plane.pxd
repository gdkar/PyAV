from av.buffer cimport Buffer
from av.frame cimport Frame
from libc.stddef cimport size_t
cimport libav as lib

cdef class Plane:
    cdef object __weakref__
#(Buffer):
    cdef Frame frame
    cdef int index
    cdef readonly size_t buffer_size
#    cdef size_t _buffer_size(self)
#    cdef void*  _buffer_ptr(self)
