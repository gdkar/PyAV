cimport libav as lib
from libc.stdint cimport uint64_t

cdef class AudioLayout(object):
    # The layout for FFMpeg; this is essentially a bitmask of channels.
    cdef readonly uint64_t layout
    cdef readonly nb_channels

    cdef readonly tuple channels

    cdef _init(self, uint64_t layout)


cdef class AudioChannel(object):
    # The channel for FFmpeg.
    cdef readonly uint64_t channel

cdef AudioLayout get_audio_layout(int channels, uint64_t c_layout)
