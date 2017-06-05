cimport libav as lib
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
        return '<av.{:s} nb_samples:{} {}hz {:s} {:s} at 0x{:x}'.format(
                self.__class__.__name__,
                self.samples or 0,
                self.rate or 0,
                self.format or 'no format',
                self.layout or 'no layout',
                id(self)
                )
    def __cinit__(self):
        self.last_pts = lib.AV_NOPTS_VALUE
        self.samples_read = 0
        self.samples_written = 0
        self.pts_per_sample = 0.

    cpdef clear(self):
        return self.drain(len(self))

    cpdef write(self, AudioFrame frame):
        """Push some samples into the queue."""

        # Take configuration from the first frame.
        if frame is None:
            raise TypeError('AudioFifo must be given an AudioFrame.')
        if not frame.ptr.nb_samples:
            return

        if not self.ptr:
            # Hold onto a copy of the attributes of the first frame to populate
            # output frames with.
            self.template = alloc_audio_frame()
            self.template._copy_internal_attributes(frame)
            self.template._init_user_attributes()

            # Figure out our "time_base".
            if frame._time_base.num and frame.ptr.sample_rate:
                self.pts_per_sample  = frame._time_base.den / float(frame._time_base.num)
                self.pts_per_sample /= frame.ptr.sample_rate
            else:
                self.pts_per_sample = 0

            self.ptr = lib.av_audio_fifo_alloc(
                <lib.AVSampleFormat>frame.ptr.format,
                len(frame.layout.channels), # TODO: Can we safely use frame.ptr.nb_channels?
                frame.ptr.nb_samples * 2, # Just a default number of samples; it will adjust.
            )
            if not self.ptr:
                raise RuntimeError('Could not allocate AVAudioFifo.')
        # Make sure nothing changed.
        elif (
            frame.ptr.format         != self.template.ptr.format or
            frame.ptr.channel_layout != self.template.ptr.channel_layout or
            frame.ptr.sample_rate    != self.template.ptr.sample_rate or
            (frame._time_base.num and self.template._time_base.num and (
                frame._time_base.num     != self.template._time_base.num or
                frame._time_base.den     != self.template._time_base.den
            ))
        ):
            raise ValueError('Frame does not match AudioFifo parameters.')
        # Assert that the PTS are what we expect.
        cdef uint64_t expected_pts
        if self.pts_per_sample and frame.ptr.pts != lib.AV_NOPTS_VALUE:
            expected_pts = <uint64_t>(self.pts_per_sample * self.samples_written)
            if frame.ptr.pts != expected_pts:
                raise ValueError('Frame.pts (%d) != expected (%d); fix or set to None.' % (frame.ptr.pts, expected_pts))

        cdef void **edata = <void**>frame.ptr.extended_data
        cdef lib.AVAudioFifo *ptr = self.ptr
        cdef int err = 0
        cdef int nb_samples = frame.ptr.nb_samples
        with nogil:
            err = lib.av_audio_fifo_write(ptr,edata,nb_samples,)
        err_check(err)
        self.samples_written += nb_samples

    cpdef drain(self, unsigned int nb_samples):
        nb_samples = nb_samples or self.samples
        nb_samples = min(nb_samples,self.samples)
        cdef lib.AVAudioFifo *ptr = self.ptr
        cdef int err = 0
        with nogil:
            err = lib.av_audio_fifo_drain(self.ptr,nb_samples)
        err_check(err)
        self.samples_read += nb_samples
        return nb_samples

    cpdef peek(self, unsigned int nb_samples=0, bint partial=False):
        return self.peek_at(nb_samples, 0, partial)

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

        cdef AudioFrame frame = alloc_audio_frame()
        frame._copy_internal_attributes(self.template)
        frame._init(
            <lib.AVSampleFormat>self.template.ptr.format,
            self.template.ptr.channel_layout,
            nb_samples,
            1, # Align?
        )
        cdef void **edata = <void**>frame.ptr.extended_data
        cdef lib.AVAudioFifo *ptr = self.ptr
        cdef int err = 0
        with nogil:
            err = lib.av_audio_fifo_peek_at(
                ptr,
                edata,
                nb_samples,
                offset
            )
        err_check(err)
        if self.pts_per_sample:
            frame.ptr.pts = <uint64_t>(self.pts_per_sample * (self.samples_read + offset))
        else:
            frame.ptr.pts = lib.AV_NOPTS_VALUE

        return frame

    cpdef read_many(self, unsigned int nb_samples = 0, bint partial=False):
        """read_many(samples, partial=False)

        Read as many frames as we can.

        :param int samples: How large for the frames to be.
        :param bool partial: If we should return a partial frame.
        :returns: A ``list`` of :class:`AudioFrame`.

        """
        cdef AudioFrame frame
        cdef list frames = list()
        while True:
            frame = self.read(nb_samples,partial=partial)
            if frame is not None:
                frames.append(frame)
            else:
                break
        return frames

    cpdef read(self, unsigned int nb_samples=0, bint partial=False):
        """Read samples from the queue.

        :param int samples: The number of samples to pull; 0 gets all.
        :param bool partial: Allow returning less than requested.
        :returns: New :class:`AudioFrame` or ``None`` (if empty).

        If the incoming frames had valid timestamps, the returned frames
        will have accurate timestamps (assuming a time_base or 1/sample_rate).

        """
        if not self.ptr or not nb_samples:
            return

        cdef int buffered_samples = self.samples
        if buffered_samples < 1:
            return
        if buffered_samples < nb_samples:
            if partial:
                nb_samples = buffered_samples
            else:
                return

        cdef AudioFrame frame = alloc_audio_frame()
        frame._copy_internal_attributes(self.template)
        frame._init(
            <lib.AVSampleFormat>self.template.ptr.format,
            self.template.ptr.channel_layout,
            nb_samples,
            1, # Align?
        )
        cdef lib.AVAudioFifo *ptr = self.ptr
        cdef void **_edata = <void**>frame.ptr.extended_data
        cdef int err = 0
        with nogil:
            err = lib.av_audio_fifo_read(
                self.ptr,
                <void **>frame.ptr.extended_data,
                nb_samples,
            )
        err_check(err)
        if self.pts_per_sample:
            frame.ptr.pts = <uint64_t>(self.pts_per_sample * self.samples_read)
        else:
            frame.ptr.pts = lib.AV_NOPTS_VALUE
        self.samples_read += nb_samples

        return frame

    def __len__(self):
        return self.samples

    @property
    def next_pts(self):
        if self.pts_per_sample:
            return (self.samples_read + self.samples) * self.pts_per_sample

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
        return self.template.rate

    @property
    def sample_rate(self):
        """Sample rate of the audio data. """
        return self.template.sample_rate

    @property
    def format(self):
        return self.template.format

    @property
    def layout(self):
        return self.template.layout

    @property
    def channels(self):
        return self.template.channels

    @property
    def time_base(self):
        return self.template.time_base
