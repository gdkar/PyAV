cimport libav as lib


cdef class Option(object):
    cdef const lib.AVOption *ptr

cdef Option wrap_option(const lib.AVOption *ptr)
cdef Option find_option(void *obj, const char *name, int opt_flags, int search_flags)
cdef object get_option (void *obj, const char *name, int search_flags)
cdef void   set_option (void *obj, const char *name, object val, int search_flags)
