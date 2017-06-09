
cdef class _Buffer:
    cdef size_t _buffer_size(self)
    cdef void* _buffer_ptr(self)


cdef class Buffer(_Buffer):
    cdef object __weakref__
