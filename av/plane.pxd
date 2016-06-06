from av.buffer cimport Buffer
from av.frame cimport Frame


cdef class Plane(Buffer):
    cdef Frame frame
    cdef int index
    cdef readonly size_t buffer_size
    cdef size_t _buffer_size(self)
    cdef void*  _buffer_ptr(self)
