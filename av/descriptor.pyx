cimport libav as lib
import weakref
from av.option cimport Option, wrap_option
from libc.stdint cimport int64_t
cdef object _cinit_sentinel = object()
cdef object _desc_cache = weakref.WeakValueDictionary()

cdef Descriptor wrap_avclass(const lib.AVClass *ptr):
    if ptr == NULL:
        return None
    cdef Descriptor cached = _desc_cache.get(<int64_t>ptr,None)
    if cached is None:
        cached = Descriptor(_cinit_sentinel)
        cached.ptr = ptr
        _desc_cache[<int64_t>ptr] = cached
    return cached

cdef class Descriptor:
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError('Cannot construct av.Descriptor')
    @property
    def name(self):
        return self.ptr.class_name if self.ptr.class_name else None

    @property
    def options(self):
        cdef const lib.AVOption *ptr
        cdef Option option
        if self._options is None:
            options = []
            ptr = self.ptr.option
            while ptr != NULL and ptr.name != NULL:
                option = wrap_option(ptr)
                options.append(option)
                ptr += 1
            self._options = tuple(options)
        return self._options

    def __repr__(self):
        return '<{} {} at 0x{:x}>'.format(self.__class__.__name__, self.name, id(self))
