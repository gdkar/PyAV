
cdef class _Buffer:
    cdef object __weakref__
    cdef size_t _buffer_size(self)
    cdef void* _buffer_ptr(self)


cdef class Buffer(_Buffer):
    pass
