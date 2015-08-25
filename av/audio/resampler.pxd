cimport libav as lib
from libc.stdint cimport int64_t
from av.audio.format cimport AudioFormat
from av.audio.frame cimport AudioFrame
from av.audio.layout cimport AudioLayout


cdef class AudioResampler(object):

    cdef lib.SwrContext *ptr

    # Source descriptors; not for public consumption.
    cdef AudioFormat src_format
    cdef AudioLayout src_layout
    cdef unsigned int src_rate

    # Destination descriptors
    cdef public AudioFormat format
    cdef public AudioLayout layout
    cdef public unsigned int rate
    cpdef resample(self, AudioFrame)
