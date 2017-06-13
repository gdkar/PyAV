cimport libav as lib


cdef class ContainerFormat:
    cdef object __weakref__

    cdef readonly str name
    @staticmethod
    cdef ContainerFormat _create(str name, str mode=*)
    cdef const lib.AVInputFormat  *iptr
    cdef const lib.AVOutputFormat *optr

cdef ContainerFormat build_container_format(const lib.AVInputFormat*, const lib.AVOutputFormat*)
