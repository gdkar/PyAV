cimport libav as lib

from av.filter.pad cimport alloc_filter_pads


cdef object _cinit_sentinel = object()

cdef Filter wrap_filter(lib.AVFilter *ptr):
    cdef Filter filter_ = Filter(_cinit_sentinel)
    filter_.ptr = ptr
    return filter_


cdef class Filter(object):

    def __cinit__(self, name):
        if name is _cinit_sentinel:
            return
        if not isinstance(name, basestring):
            raise TypeError('takes a filter name as a string')
        self.ptr = lib.avfilter_get_by_name(name)
        if not self.ptr:
            raise ValueError('no filter %s' % name)

    @property
    def name(self):
        return self.ptr.name

    @property
    def description(self):
        return self.ptr.description

    @property
    def dynamic_inputs(self):
        return bool(self.ptr.flags & lib.AVFILTER_FLAG_DYNAMIC_INPUTS)

    @property
    def dynamic_outputs(self):
        return bool(self.ptr.flags & lib.AVFILTER_FLAG_DYNAMIC_OUTPUTS)

    @property
    def inputs(self):
        if self._inputs is None:
            self._inputs = alloc_filter_pads(self, self.ptr.inputs, True)
        return self._inputs

    @property
    def outputs(self):
        if self._outputs is None:
            self._outputs = alloc_filter_pads(self, self.ptr.outputs, False)
        return self._outputs
