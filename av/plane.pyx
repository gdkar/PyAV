from libc.string cimport memcpy
from cpython cimport PyBuffer_FillInfo
from cpython.buffer cimport PyObject_CheckBuffer, PyObject_GetBuffer, PyBUF_SIMPLE,PyBUF_WRITABLE, PyBUF_ND, PyBUF_STRIDES, PyBUF_INDIRECT,  PyBuffer_Release, Py_buffer
from av.bytesource cimport ByteSource, bytesource
from av.utils cimport err_check
cdef class Plane:
    def __cinit__(self, Frame frame, int index):
        self.frame = frame
        self.index = index
        self.buffer_size = frame.ptr.linesize[index]
    def __repr__(self):
        return '<av.%s at 0x%x>' % (self.__class__.__name__, id(self))
    def __len__(self):
        return self.buffer_size
    @property
    def line_size(self):
        """Bytes per horizontal line in this plane."""
        return self.frame.ptr.linesize[self.index]
    @property
    def ptr(self):
        return <long>self.frame.ptr.extended_data[self.index]
    def to_bytes(self):
        return bytes(self)
        return <bytes>(<char*>self.frame.ptr.extended_data[self.index])[:self.buffer_size]
    def update(self, input):
        """Replace the data in this plane with the given buffer."""
        cdef ByteSource source = bytesource(input)
        if source.length != self.buffer_size:
            raise ValueError('got %d bytes; need %d bytes' % (len(input), self.buffer_size))
        memcpy(<void*>self.frame.ptr.extended_data[self.index], source.ptr, self.buffer_size)
    def update_from_string(self, input):
        """Replace the data in this plane with the given string.

        Deprecated; use :meth:`Plane.update_buffer` instead.

        """
        self.update(input)
    # Legacy buffer support. For `buffer` and PIL.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

#    def __getsegcount__(self, Py_ssize_t *len_out):
#        if len_out != NULL:
#            len_out[0] = <Py_ssize_t>self.buffer_size
#        return 1

#    def __getreadbuffer__(self, Py_ssize_t index, void **data):
#        if index:
#            raise RuntimeError("accessing non-existent buffer segment")
#        data[0] = <void*>self.frame.ptr.extended_data[self.index]
#        return <Py_ssize_t>self.buffer_size

#    def __getwritebuffer__(self, Py_ssize_t index, void **data):
#        if index:
#            raise RuntimeError("accessing non-existent buffer segment")
#        data[0] = <void*>self.frame.ptr.extended_data[self.index]
#        return <Py_ssize_t>self.buffer_size
    def __getbuffer__(self, Py_buffer *view, int flags):
        if self.frame is None:
            raise BufferError
        cdef lib.AVFrame *ptr = self.frame.ptr

        cdef lib.AVBufferRef  *buf = NULL
        cdef int err = 0
        cdef ptrdiff_t data_offset
        cdef int index = self.index
        buf = lib.av_frame_get_plane_buffer(ptr, index)
        if buf == NULL:
            raise BufferError
        if buf:
            with nogil:
                buf = lib.av_buffer_ref(buf)
        if buf == NULL:
            raise BufferError

        cdef bint want_write = (flags & PyBUF_WRITABLE == PyBUF_WRITABLE)
        err = PyBuffer_FillInfo(view, self, ptr.extended_data[self.index], self.buffer_size, want_write, flags)
        if err < 0 and buf != NULL:
            with nogil:
                lib.av_buffer_unref(&buf)
        view.internal = <void*>buf
        err_check(err)
    def __releasebuffer__(self, Py_buffer *view):
        if view == NULL:
            return

        cdef lib.AVBufferRef **refp = <lib.AVBufferRef**>&view.internal
        if refp[0]:
            lib.av_buffer_unref(refp)


    # New-style buffer support.
#    def __getbuffer__(self, Py_buffer *view, int flags):
#        PyBuffer_FillInfo(view, self, <void *> self.frame.ptr.extended_data[self.index], self.buffer_size, 0, flags)
