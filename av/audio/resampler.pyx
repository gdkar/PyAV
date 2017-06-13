from libc.stdint cimport uint64_t

cimport libav as lib

from av.audio.fifo cimport AudioFifo
from av.audio.format cimport get_audio_format
from av.audio.frame cimport alloc_audio_frame
from av.audio.layout cimport get_audio_layout
from av.utils cimport err_check

cdef class AudioResampler(object):

    """An Audio Resampler."""
    def __cinit__(self, format=None, layout=None, rate=None):
        """:param AudioFormat or str: the output format
        :param AudioLayout or strlayout: the output layout
        :param int or None rate: the output sample rate
        """

        if format is not None:
            self.format = format if isinstance(format, AudioFormat) else AudioFormat(format)
        else: self.format = None
        if layout is not None:
            self.layout = layout if isinstance(layout, AudioLayout) else AudioLayout(layout)
        else:
            self.layout = None
        self.rate = int(rate) if rate else 0
        self.ptr = lib.swr_alloc()
        if not self.ptr:
            raise ValueError("could not create SwrContext")

    def __dealloc__(self):
        if self.ptr: lib.swr_close(self.ptr)
        lib.swr_free(&self.ptr)

    cpdef resample(self, AudioFrame frame):
        """Resample an audio frame, and return the result

        :param AudioFrame frame: input frame
        :returns: AudioFrame of output or None
        """

        # Take source settings from the first frame.
        if (not self.src_format or not self.src_layout or not self.src_rate):
            if not frame:
                raise ValueError("must configure resampler with non-null frame.")
            self.src_format = get_audio_format(<lib.AVSampleFormat>frame.ptr.format)
            self.src_layout = get_audio_layout(0,frame.ptr.channel_layout)
            self.src_rate   = frame.ptr.sample_rate
        self.format = self.format or self.src_format
        self.layout = self.layout or self.src_layout
        self.rate   = self.rate   or self.src_rate
        # The example "loop" as given in the FFmpeg documentation looks like:
        # uint8_t **input;
        # int in_samples;
        # while (get_input(&input, &in_samples)) {
        #     uint8_t *output;
        #     int out_samples = av_rescale_rnd(swr_get_delay(swr, 48000) +
        #                                      in_samples, 44100, 48000, AV_ROUND_UP);
        #     av_samples_alloc(&output, NULL, 2, out_samples,
        #                      AV_SAMPLE_FMT_S16, 0);
        #     out_samples = swr_convert(swr, &output, out_samples,
        #                                      input, in_samples);
        #     handle_output(output, out_samples);
        #     av_freep(&output);
        # }

        # Estimate out how many samples this will create; it will be high.
        # My investigations say that this swr_get_delay is not required, but
        # it is in the example loop, and avresample (as opposed to swresample)
        # may require it.
        cdef AudioFrame output    = alloc_audio_frame()
        output.ptr.sample_rate    = self.rate
        output.ptr.format         = self.format.sample_fmt
        output.ptr.channel_layout = self.layout.layout
        if not lib.swr_is_initialized(self.ptr):
            err_check(lib.swr_config_frame(self.ptr,output.ptr,frame.ptr))
            err_check(lib.swr_init(self.ptr))
        cdef int output_nb_samples = lib.av_rescale_rnd(
            lib.swr_get_delay(self.ptr, self.rate) + frame.ptr.nb_samples,
            self.rate,
            self.src_rate,
            lib.AV_ROUND_UP,
        ) if frame else lib.swr_get_delay(self.ptr, self.rate)

        # There aren't any frames coming, so no new frame pops out.
        if not output_nb_samples: return
        output._init(
            self.format.sample_fmt,
            self.layout.layout,
            0,
            0, # Align?
        )
        if lib.swr_convert_frame(self.ptr,output.ptr,frame.ptr) < 0:
            err_check(lib.swr_config_frame(self.ptr,output.ptr,frame.ptr))
            err_check(lib.swr_convert_frame(self.ptr,output.ptr,frame.ptr))
#        output.ptr.nb_samples = err_check(lib.swr_convert(
#            self.ptr,
#            output.ptr.extended_data,
#            output_nb_samples,
#            frame.ptr.extended_data if frame else NULL,
#            frame.ptr.nb_samples if frame else 0
#        ))

        # Copy some attributes.
        output._copy_attributes_from(frame)
        # Empty frame.
        if output.ptr.nb_samples <= 0:
            return
        # Recalculate linesize since the initial number of samples was
        # only an estimate.
        output._recalc_linesize()
        return output
