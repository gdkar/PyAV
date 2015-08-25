from libc.stdint cimport int8_t, uint8_t, int64_t, uint64_t
cimport libav as lib
from av.utils cimport avrational_to_fraction, to_avrational
cdef object _cinit_sentinel = object()

cdef Option wrap_option(lib.AVOption *ptr):
    if ptr == NULL: return None
    cdef Option obj = Option(_cinit_sentinel)
    obj.ptr = ptr
    return obj

cdef Option find_option( void *obj, const char *name, int opt_flags, int search_flags):
    return wrap_option(lib.av_opt_find(obj, name, NULL, opt_flags, search_flags))

cdef dict _TYPE_NAMES = {
    lib.AV_OPT_TYPE_FLAGS: 'FLAGS',   
    lib.AV_OPT_TYPE_INT: 'INT',     
    lib.AV_OPT_TYPE_INT64: 'INT64',   
    lib.AV_OPT_TYPE_DOUBLE: 'DOUBLE',  
    lib.AV_OPT_TYPE_FLOAT: 'FLOAT',   
    lib.AV_OPT_TYPE_STRING: 'STRING',  
    lib.AV_OPT_TYPE_RATIONAL: 'RATIONAL',    
    lib.AV_OPT_TYPE_BINARY: 'BINARY',  
    #lib.AV_OPT_TYPE_DICT: 'DICT', # Recent addition; does not always exist.
    lib.AV_OPT_TYPE_CONST: 'CONST',   
    #lib.AV_OPT_TYPE_IMAGE_SIZE: 'IMAGE_SIZE',  
    #lib.AV_OPT_TYPE_PIXEL_FMT: 'PIXEL_FMT',   
    #lib.AV_OPT_TYPE_SAMPLE_FMT: 'SAMPLE_FMT',  
    #lib.AV_OPT_TYPE_VIDEO_RATE: 'VIDEO_RATE',  
    #lib.AV_OPT_TYPE_DURATION: 'DURATION',    
    #lib.AV_OPT_TYPE_COLOR: 'COLOR',   
    #lib.AV_OPT_TYPE_CHANNEL_LAYOUT: 'CHANNEL_LAYOUT',  
}

cdef object get_option( void *obj, const char *name, int search_flags ):
    cdef lib.AVOption * opt = lib.av_opt_find ( obj, name, NULL, 0, search_flags )
    cdef int64_t INT64
    cdef double DOUBLE
    cdef uint8_t *STRING
    cdef lib.AVRational RATIONAL
    if opt.type is lib.AV_OPT_TYPE_INT or opt.type is lib.AV_OPT_TYPE_INT64:
        lib.av_opt_get_int(obj, name, search_flags, &INT64)
        return INT64
    elif opt.type is lib.AV_OPT_TYPE_FLOAT or opt.type is lib.AV_OPT_TYPE_DOUBLE:
        lib.av_opt_get_double(obj, name, search_flags, &DOUBLE)
        return DOUBLE 
    elif opt.type is lib.AV_OPT_TYPE_RATIONAL:
        lib.av_opt_get_q(obj, name, search_flags, &RATIONAL)
        return avrational_to_fraction(&RATIONAL)
    else:
        lib.av_opt_get(obj, name, search_flags, &STRING)
        ret = str(STRING)
        lib.av_freep(&STRING)
        return ret

cdef void set_option( void *obj, const char *name, object val, int search_flags):
    cdef lib.AVOption * opt = lib.av_opt_find ( obj, name, NULL, 0, search_flags )
    cdef int64_t INT64
    cdef lib.AVPixelFormat pixfmt
    cdef lib.AVSampleFormat smpfmt
    cdef double DOUBLE
    cdef lib.AVRational RATIONAL
    if isinstance(val,str):
        lib.av_opt_set(obj, name, val, search_flags)
    elif opt.type is lib.AV_OPT_TYPE_STRING:
        lib.av_opt_set(obj, name, str(val), search_flags)
    elif opt.type is lib.AV_OPT_TYPE_INT or opt.type is lib.AV_OPT_TYPE_INT64 or opt.type is lib.AV_OPT_TYPE_CHANNEL_LAYOUT:
        INT64 = <int64_t>val
        lib.av_opt_set_int(obj,name,val,search_flags)
    elif opt.type is lib.AV_OPT_TYPE_FLOAT or opt.type is lib.AV_OPT_TYPE_DOUBLE:
        DOUBLE = val
        lib.av_opt_set_double(obj,name,DOUBLE,search_flags)
    elif opt.type is lib.AV_OPT_TYPE_PIXEL_FMT:
        pixfmt = val
        lib.av_opt_set_pixel_fmt(obj,name,pixfmt,search_flags)
    elif opt.type is lib.AV_OPT_TYPE_SAMPLE_FMT:
        smpfmt = val
        lib.av_opt_set_sample_fmt(obj,name,smpfmt,search_flags)
    elif opt.type is lib.AV_OPT_TYPE_RATIONAL:
        to_avrational(val,&RATIONAL)
        lib.av_opt_set_q(obj,name,RATIONAL,search_flags)
    else:
        lib.av_opt_set  (obj,name,str(val),search_flags)

    pass
cdef class Option(object):

    def __cinit__(self, sentinel):
        if sentinel != _cinit_sentinel:
            raise RuntimeError('Cannot construct av.Option')

    property name:
        def __get__(self):
            return self.ptr.name

    property type:
        def __get__(self):
            return _TYPE_NAMES[self.ptr.type]

    property help:
        def __get__(self):
            return self.ptr.help if self.ptr.help != NULL else ''
            
    def __repr__(self):
        return '<av.%s %s at 0x%x>' % (self.__class__.__name__, self.name, id(self))

