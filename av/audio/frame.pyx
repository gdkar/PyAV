from av.audio.format cimport AudioFormat, get_audio_format
from av.audio.layout cimport AudioLayout, get_audio_layout
from av.audio.plane cimport AudioPlane
from av.utils cimport err_check
from libc.stdint cimport int64_t, uint64_t, int32_t, uint32_t, int16_t, uint16_t, int8_t, uint8_t
import fractions

cdef object _cinit_bypass_sentinel

cdef AudioFrame alloc_audio_frame():
    """Get a mostly uninitialized AudioFrame.

    You MUST call AudioFrame._init(...) or AudioFrame._init_properties()
    before exposing to the user.

    """
    return AudioFrame.__new__(AudioFrame, _cinit_bypass_sentinel)


cdef class AudioFrame(Frame):

    """A frame of audio."""

    def __cinit__(self, format='s16', layout='stereo', samples=0, align=True):
        if format is _cinit_bypass_sentinel:
            return
        self._init(
            AudioFormat(format).sample_fmt,
            AudioLayout(layout).layout,
            samples,
            align,
        )
    cdef _init(self, lib.AVSampleFormat format, uint64_t layout, unsigned int nb_samples, bint align):
        self.align = align
        cdef int rate = self.ptr.sample_rate
        cdef int64_t pts = self.ptr.pts
        with nogil:
            lib.av_frame_unref(self.ptr)
        self.ptr.nb_samples = nb_samples
        self.ptr.format         = <int>format
        self.ptr.channel_layout = layout
        self.ptr.sample_rate    = rate
        self.ptr.pts            = pts
        cdef int err = 0
        # HACK: It really sucks to do this twice.
        self._init_properties()
        cdef size_t buffer_size
        if self.layout.channels and nb_samples:
            # Cleanup the old buffer.
            # Get a new one.
            self._buffer_size = err_check(lib.av_samples_get_buffer_size(
                NULL,
                len(self.layout.channels),
                nb_samples,
                format,
                align
            ))
            with nogil:
                err = lib.av_frame_get_buffer(self.ptr, align)
            err_check(err)
#            # Connect the data pointers to the buffer.
#            err_check(lib.avcodec_fill_audio_frame(
#                self.ptr,
#                len(self.layout.channels),
#                <lib.AVSampleFormat>self.ptr.format,
#                self._buffer,
#                self._buffer_size,
#                self.align
#           ))

            self._init_planes(AudioPlane)

    cdef _recalc_linesize(self):
        lib.av_samples_get_buffer_size(
            self.ptr.linesize,
            len(self.layout.channels),
            self.ptr.nb_samples,
            <lib.AVSampleFormat>self.ptr.format,
            self.align
        )
        # We need to reset the buffer_size on the AudioPlane/s. This is
        # an easy, if inefficient way.
        self._init_planes(AudioPlane)

    cdef _init_properties(self):
        self.layout         = get_audio_layout(0, self.ptr.channel_layout)
        self.format         = get_audio_format(<lib.AVSampleFormat>self.ptr.format)
        self.nb_channels    = lib.av_get_channel_layout_nb_channels(self.ptr.channel_layout)
        self.nb_planes      = self.nb_channels if lib.av_sample_fmt_is_planar(<lib.AVSampleFormat>self.ptr.format) else 1
        self.ptr.pts        = lib.av_frame_get_best_effort_timestamp ( self.ptr )
        self._init_planes(AudioPlane)
    def __dealloc__(self):
        pass
#        lib.av_freep(&self._buffer)
    def __repr__(self):
        return '<av.%s %d, %d samples at %dHz, %s, %s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.samples,
            self.rate,
            self.layout.name,
            self.format.name,
            id(self),
        )
    @property
    def samples(self):
        """Number of audio samples (per channel) """
        if self.ptr != NULL:
            return self.ptr.nb_samples

    @property
    def rate(self):
        """Sample rate of the audio data. """
        if self.ptr != NULL:
            return self.ptr.sample_rate

    @rate.setter
    def rate(self, rate):
        if self.ptr != NULL:
            self.ptr.sample_rate = rate
            self.time_base = fractions.Fraction(1,rate)

    def to_ndarray(self,**kwargs):
        import numpy as np
        cdef str fname = self.format.packed.name
        if fname == 'dbl': dtype=np.float64
        elif fname=='flt': dtype=np.float32
        elif fname=='s32': dtype=np.int32
        elif fname=='s16': dtype=np.int16
        elif fname=='s8' : dtype=np.int8
        elif fname=='u8' : dtype=np.uint8
        else             : raise TypeError("type not convertible")
        if self.format.is_packed:
            dtype=np.dtype((dtype,len(self.layout.channels)))
            return np.frombuffer(self.planes[0],dtype)
        else:
            return np.vstack(np.frombuffer(plane,dtype=dtype) for plane in self.planes).T
    @classmethod
    def from_ndarray(cls, array):
        # TODO: We could stand to be more accepting.
        if array.ndim == 1:
            layout = AudioLayout(1)
        elif array.ndim == 2:
            layout = AudioLayout(array.shape[1])
        else:
            raise ValueError('array must be one or two dimensional')

        if array.dtype ==   'uint8':  format = 'u8p'
        elif array.dtype == 'int16':  format = 's16p'
        elif array.dtype == 'int32':  format = 's32p'
        elif array.dtype == 'int64':  format = 's64p'
        elif array.dtype == 'float32':format = 'fltp'
        elif array.dtype == 'float64':format = 'dblp'
        else:
            raise ValueError('array dtype must be one of: uint8, int16, int32, int64, float32, float64')
        frame = cls(format, layout, array.shape[0])
        if array.ndim == 1:
            frame.planes[0].update(array)
        else:
            for i in range(array.shape[1]):
                frame.planes[i].update(array[::,i])

        return frame
