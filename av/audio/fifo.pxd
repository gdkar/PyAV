from libc.stdint cimport int64_t, uint64_t

cimport libav as lib

from av.audio.layout cimport AudioLayout
from av.audio.format cimport AudioFormat
from av.audio.frame cimport AudioFrame


cdef class AudioFifo:

    cdef lib.AVAudioFifo *ptr

    cdef AudioFrame template

    cdef readonly uint64_t samples_written
    cdef readonly uint64_t samples_read
    cdef readonly double pts_per_sample

    cdef int64_t         last_pts
    cdef int64_t         pts_offset

    cpdef write(self, AudioFrame frame)
    cpdef read(self, unsigned int nb_samples=*, bint partial=*)
    cpdef read_many(self,unsigned int nb_samples=*, bint partial=*)
    cpdef peek(self, unsigned int nb_samples=*, bint partial=*)
    cpdef clear(self)
    cpdef drain(self, unsigned int nb_samples)
    cpdef peek_at(self, unsigned int nb_samples=*,unsigned int offset=*, bint partial=*)
