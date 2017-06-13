from av.audio.format cimport get_audio_format
from av.audio.frame cimport alloc_audio_frame
from av.audio.layout cimport get_audio_layout
from av.container.core cimport Container
from av.frame cimport Frame
from av.packet cimport Packet
from av.utils cimport err_check
from libc.errno cimport EAGAIN, EINVAL, EFAULT

cdef class AudioStream(Stream):

    cdef _init(self, Container container, lib.AVStream *stream):
        Stream._init(self, container, stream)

        # Sometimes there isn't a layout set, but there are a number of
        # channels. Assume it is the default layout.
        self.layout = get_audio_layout(self._codec_context.channels, self._codec_context.channel_layout)
        if not self._codec_context.channel_layout:
            self._codec_context.channel_layout = self.layout.layout

        self.format = get_audio_format(self._codec_context.sample_fmt)

    def __repr__(self):
        return '<av.%s #%d %s at %dHz, %s, %s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.name,
            self.rate,
            self.layout.name,
            self.format.name,
            id(self),
        )
    @property
    def frame_size(self):
        """Number of samples per channel in an audio frame."""
        return self._codec_context.frame_size

    @property
    def rate(self):
        """samples per second """
        return self._codec_context.sample_rate
    @rate.setter
    def rate(self, int value):
        self._codec_context.sample_rate = value

    @property
    def  channels(self):
        return self._codec_context.channels
    cdef AudioFrame _alloc_frame(self):
        return alloc_audio_frame()
#    self.next_frame = alloc_audio_frame()
#    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed):
#        if not self.next_frame:
#            self.next_frame = self.alloc_frame()
#        cdef int completed_frame = 0
#        cdef int err
#        cdef AudioFrame frame = self.next_frame
#        with nogil:
#            err = lib.avcodec_receive_frame(self._codec_context, frame.ptr)
#            if err < 0:
#                if err == lib.AVERROR_EOF:
#                    lib.avcodec_flush_buffers(self._codec_context)
#                elif err != lib.AVERROR(EAGAIN):
#                    with gil:
#                        err_check(err)
#            else:
#                completed_frame = 1
#        if packet:
#            with nogil:
#                err = lib.avcodec_send_packet(self._codec_context, packet)
#            if err == 0:
#                data_consumed[0] = packet.size
#            else:
#                data_consumed[0] = 0
#        if not completed_frame:
#            return
#        frame.ptr.pts = lib.av_frame_get_best_effort_timestamp ( frame.ptr )
#        self.next_frame       = None
#        frame._init_properties()
#        return frame

    cpdef encode(self, AudioFrame input_frame):
        """Encodes a frame of audio, returns a packet if one is ready.
        The output packet does not necessarily contain data for the most recent frame,
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.
        """

        self._weak_container().start_encoding()
        if not self.resampler:
            self.resampler = AudioResampler(
                self.format,
                self.layout,
                self._codec_context.sample_rate
            )
        if not self.fifo:
            self.fifo = AudioFifo()

        # if input_frame:
        #     print 'input_frame.ptr.pts', input_frame.ptr.pts

        # Resample, and re-chunk. A None frame will flush the resampler,
        # and then flush the fifo.
        cdef AudioFrame resampled_frame = self.resampler.resample(input_frame)
        if resampled_frame:
            self.fifo.write(resampled_frame)
            # print 'resampled_frame.ptr.pts', resampled_frame.ptr.pts

        # Pull partial frames if we were requested to flush (via a None frame).
        cdef AudioFrame fifo_frame = self.fifo.read(self._codec_context.frame_size, partial=input_frame is None)

        cdef Packet packet = Packet()
        cdef int got_packet = 0

        if fifo_frame:

            # If the fifo_frame has a valid pts, scale it to the codec's time_base.
            # Remember that the AudioFifo time_base is always 1/sample_rate!
            if fifo_frame.ptr.pts != lib.AV_NOPTS_VALUE:
                fifo_frame.ptr.pts = lib.av_rescale_q(
                    fifo_frame.ptr.pts,
                    fifo_frame._time_base,
                    self._codec_context.time_base
                )
            else:
                fifo_frame.ptr.pts = lib.av_rescale(
                    self._codec_context.frame_number,
                    self._codec_context.sample_rate,
                    self._codec_context.frame_size,
                )

        err_check(lib.avcodec_encode_audio2(
            self._codec_context,
            packet.ptr,
            fifo_frame.ptr if fifo_frame is not None else NULL,
            &got_packet,
        ))
        if not got_packet:
            return

        # Rescale some times which are in the codec's time_base to the
        # stream's time_base.
        if packet.ptr.pts != lib.AV_NOPTS_VALUE:
            packet.ptr.pts = lib.av_rescale_q(
                packet.ptr.pts,
                self._codec_context.time_base,
                self._stream.time_base
            )
        if packet.ptr.dts != lib.AV_NOPTS_VALUE:
            packet.ptr.dts = lib.av_rescale_q(
                packet.ptr.dts,
                self._codec_context.time_base,
                self._stream.time_base
            )
        if packet.ptr.duration > 0:
            packet.ptr.duration = lib.av_rescale_q(
                packet.ptr.duration,
                self._codec_context.time_base,
                self._stream.time_base
            )

        # `coded_frame` is "the picture in the bitstream"; does this make
        # sense for audio?
        if self._codec_context.coded_frame:
            if self._codec_context.coded_frame.key_frame:
                packet.ptr.flags |= lib.AV_PKT_FLAG_KEY

        packet.ptr.stream_index = self._stream.index
        packet.stream = self

        return packet
