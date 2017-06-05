
cdef class Plane(Buffer):

    def __cinit__(self, Frame frame, int index):
        self.frame = frame
        self.index = index

    def __repr__(self):
        return '<av.%s at 0x%x>' % (self.__class__.__name__, id(self))

    @property
    def line_size(self):
        """Bytes per horizontal line in this plane."""
        return self.frame.ptr.linesize[self.index]
    @property
    def ptr(self):
        return <long>self.frame.ptr.extended_data[self.index]

    cdef size_t _buffer_size(self):
        return self.frame.ptr.linesize[self.index]

    cdef void*  _buffer_ptr(self):
        return self.frame.ptr.extended_data[self.index]

    def update(self, input):
        """Replace the data in this plane with the given string.

        Deprecated; use :meth:`Plane.update_buffer` instead.

        """
        self.update_buffer(input)

    def update_from_string(self, input):
        """Replace the data in this plane with the given string.

        Deprecated; use :meth:`Plane.update_buffer` instead.

        """
        self.update_buffer(input)
