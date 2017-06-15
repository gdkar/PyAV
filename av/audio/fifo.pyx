from av.audio.format cimport get_audio_format
from av.audio.frame cimport alloc_audio_frame
from av.audio.layout cimport get_audio_layout
from av.utils cimport err_check, to_avrational, avrational_to_fraction
from fractions import Fraction

cdef class AudioFifo:

    """A simple Audio FIFO (First In First Out) Buffer."""

    def __dealloc__(self):
        lib.av_audio_fifo_free(self.ptr)

    def __repr__(self):
        return '<av.{:s} nb_samples:{:d} {:d}hz {:s} {:s} at 0x{:x}'.format(
                self.__class__.__name__,
                self.samples or 0,
                self.rate or 0,
                self.format.name if self.format is not None else 'no format',
                self.layout.name if self.layout is not None else 'no layout',
                id(self)
                )
    def __cinit__(self):
        self.last_pts = lib.AV_NOPTS_VALUE
        self.pts_offset = 0

    cpdef write(self, AudioFrame frame):
        """Push some samples into the queue."""

        # Take configuration from the first frame.
        if not self.ptr:

            self.format = get_audio_format(<lib.AVSampleFormat>frame.ptr.format)
            self.layout = get_audio_layout(0, frame.ptr.channel_layout)
            self._time_base.num = frame._time_base.num
            self._time_base.den = frame._time_base.den
            self._rate = frame.ptr.sample_rate
            self.ptr = lib.av_audio_fifo_alloc(
                self.format.sample_fmt,
                len(self.layout.channels),
                frame.ptr.nb_samples * 4, # Just a default number of samples; it will adjust.
            )
            if not self.ptr:
                raise ValueError('could not create fifo')
        # Make sure nothing changed.
        else:
            if (
                frame.ptr.format         != self.format.sample_fmt or
                frame.ptr.channel_layout != self.layout.layout or
                frame.ptr.sample_rate    != self.rate
            ):
                raise ValueError('frame does not match fifo parameters')
        if frame.ptr.pts != lib.AV_NOPTS_VALUE:
            self.last_pts   = frame.ptr.pts
            self.pts_offset = int(frame.ptr.nb_samples  / ( self.time_base * self.rate))

        err_check(lib.av_audio_fifo_write(
            self.ptr,
            <void **>frame.ptr.extended_data,
            frame.ptr.nb_samples,
        ))

    cpdef drain(self, unsigned int nb_samples):
        nb_samples = nb_samples or self.samples
        nb_samples = min(nb_samples,self.samples)
        err_check(lib.av_audio_fifo_drain(self.ptr,nb_samples))
        self.pts_offset -= int(nb_samples / (self.rate * self.time_base))
        return nb_samples

    cpdef peek(self, unsigned int nb_samples=0, bint partial=False):
        if not self.samples:
            return
        nb_samples = nb_samples or self.samples
        if not nb_samples:
            return
        if not partial and self.samples < nb_samples:
            return
        cdef int ret
        cdef int linesize
        cdef int sample_size
        cdef AudioFrame frame = alloc_audio_frame()
        frame._time_base   = self._time_base
        frame.ptr.sample_rate = self.rate
        frame._init(
            self.format.sample_fmt,
            self.layout.layout,
            nb_samples,
            1)

#        frame._init(
#            self.format.sample_fmt,
#            self.layout.layout,
##            nb_samples,
#            1, # Align?
#        )
        err_check(lib.av_audio_fifo_peek(
            self.ptr,
            <void **>frame.ptr.extended_data,
            nb_samples,
        ))
        frame.ptr.channel_layout = self.layout.layout
        if self.last_pts != lib.AV_NOPTS_VALUE:
            frame.ptr.pts = self.last_pts - self.pts_offset
        frame._recalc_linesize()
        return frame

    cpdef peek_at(self, unsigned int nb_samples=0,unsigned int offset=0, bint partial=False):
        if not self.samples:
            return

        if offset >= self.samples:
            return

        nb_samples = nb_samples or (self.samples - offset)
        if not nb_samples:
            return

        if not partial and self.samples < nb_samples + offset:
            return

        cdef int ret
        cdef int linesize
        cdef int sample_size
        cdef AudioFrame frame = alloc_audio_frame()
        frame._init(
            self.format.sample_fmt,
            self.layout.layout,
            nb_samples,
            1, # Align?
        )
        err_check(lib.av_audio_fifo_peek_at(
            self.ptr,
            <void **>frame.ptr.extended_data,
            nb_samples,
            offset
        ))
        frame.ptr.sample_rate    = self.rate
        frame._time_base         = self._time_base
        frame.ptr.channel_layout = self.layout.layout
        if self.last_pts != lib.AV_NOPTS_VALUE:
            frame.ptr.pts = self.last_pts - self.pts_offset + int(offset / self.rate / self.time_base)

        return frame

    cpdef read(self, unsigned int nb_samples=0, bint partial=False):
        """Read samples from the queue.

        :param int samples: The number of samples to pull; 0 gets all.
        :param bool partial: Allow returning less than requested.
        :returns: New :class:`AudioFrame` or ``None`` (if empty).

        If the incoming frames had valid timestamps, the returned frames
        will have accurate timestamps (assuming a time_base or 1/sample_rate).

        """

        if not self.samples:
            return
        nb_samples = nb_samples or self.samples
        if not nb_samples:
            return
        if not partial and self.samples < nb_samples:
            return
        cdef int ret
        cdef int linesize
        cdef int sample_size
        cdef AudioFrame frame = alloc_audio_frame()
        frame._init(
            self.format.sample_fmt,
            self.layout.layout,
            nb_samples,
            1, # Align?
        )
        err_check(lib.av_audio_fifo_read(
            self.ptr,
            <void **>frame.ptr.extended_data,
            nb_samples,
        ))
        frame.ptr.sample_rate = self.rate
        frame._time_base   = self._time_base
        frame.ptr.channel_layout = self.layout.layout
        if self.last_pts != lib.AV_NOPTS_VALUE:
            frame.ptr.pts = self.last_pts - self.pts_offset
            self.pts_offset -= int(frame.samples / self.rate / self.time_base)

        frame._recalc_linesize()
        return frame
    def __len__(self):
        return self.samples
    @property
    def next_pts(self):
        if self.last_pts != lib.AV_NOPTS_VALUE:
            return self.last_pts - self.pts_offset
    @property
    def samples(self):
        """Number of audio samples (per channel) """
        if self.ptr != NULL:
            return lib.av_audio_fifo_size(self.ptr)
        else:
            return 0
    @property
    def rate(self):
        """Sample rate of the audio data. """
        return self._rate
    @property
    def time_base(self):
        return avrational_to_fraction(&self._time_base)
