from libc.stdint cimport int64_t

from av.container.core cimport Container
from av.frame cimport Frame
from av.packet cimport Packet
from av.utils cimport avrational_to_fraction, to_avrational
from av.utils cimport err_check
from av.video.format cimport get_video_format, VideoFormat
from av.video.frame cimport alloc_video_frame


cdef class VideoStream(Stream):

    cdef _init(self, Container container, lib.AVStream *stream):
        Stream._init(self, container, stream)
        self.last_w = 0
        self.last_h = 0
        self.encoded_frame_count = 0
        self._build_format()
    def __repr__(self):
        return '<av.%s #%d %s, %s %dx%d at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.name,
            self.format.name if self.format else None,
            self._codec_context.width,
            self._codec_context.height,
            id(self),
        )
    cdef _build_format(self):
        if self._codec_context:
            self.format = get_video_format(<lib.AVPixelFormat>self._codec_context.pix_fmt, self._codec_context.width, self._codec_context.height)
        else:self.format = None
    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        # Create a frame if we don't have one ready.
        if not self.next_frame:
            self.next_frame = alloc_video_frame()
        # Decode video into the frame.
        cdef int completed_frame = 0
        cdef int result
        with nogil:result = lib.avcodec_decode_video2(self._codec_context, self.next_frame.ptr, &completed_frame, packet)
        data_consumed[0] = err_check(result)
        if not completed_frame:return
        # Check if the frame size has changed so that we can always have a
        # SwsContext that is ready to go.
        if self.last_w != self._codec_context.width or self.last_h != self._codec_context.height:
            self.last_w = self._codec_context.width
            self.last_h = self._codec_context.height
            self.buffer_size = lib.avpicture_get_size(
                self._codec_context.pix_fmt,
                self._codec_context.width,
                self._codec_context.height,
            )
            # Create a new SwsContextProxy
            self.reformatter = VideoReformatter()
        # We are ready to send this one off into the world!
        cdef VideoFrame frame = self.next_frame
        self.next_frame = None
        # Tell frame to finish constructing user properties.
        frame._init_properties()
        # Share our SwsContext with the frames. Most of the time they will end
        # up using the same settings as each other, so it makes sense to cache
        # it like this.
        frame.reformatter = self.reformatter
        return frame
    cpdef encode(self, VideoFrame frame=None):
        """Encodes a frame of video, returns a packet if one is ready.
        The output packet does not necessarily contain data for the most recent frame,
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.
        """

        # setup formatContext for encoding
        self._weak_container().start_encoding()
        if not self.reformatter:self.reformatter = VideoReformatter()
        cdef VideoFrame formated_frame
        cdef Packet packet
        cdef int got_output
        cdef VideoFormat pixel_format
        if frame:
            # don't reformat if format matches
            pixel_format = frame.format
            if pixel_format.pix_fmt == self.format.pix_fmt and \
                        frame.width == self._codec_context.width and frame.height == self._codec_context.height:
                formated_frame = frame
            else:
                frame.reformatter = self.reformatter
                formated_frame = frame._reformat(
                    self._codec_context.width,
                    self._codec_context.height,
                    self.format.pix_fmt,
                    lib.SWS_CS_DEFAULT,
                    lib.SWS_CS_DEFAULT
                )
        else:
            # Flushing
            formated_frame = None
        packet = Packet()
        packet.ptr.data = NULL #packet data will be allocated by the encoder
        packet.ptr.size = 0
        if formated_frame:
            # It has a pts, so adjust it.
            if formated_frame.ptr.pts != lib.AV_NOPTS_VALUE:
                formated_frame.ptr.pts = lib.av_rescale_q(
                    formated_frame.ptr.pts,
                    formated_frame._time_base, #src
                    self._codec_context.time_base,
                )
            # There is no pts, so create one.
            else:formated_frame.ptr.pts = <int64_t>self.encoded_frame_count
            self.encoded_frame_count += 1
            ret = err_check(lib.avcodec_encode_video2(self._codec_context, packet.ptr, formated_frame.ptr, &got_output))
        else:
            # Flushing
            ret = err_check(lib.avcodec_encode_video2(self._codec_context, packet.ptr, NULL, &got_output))
        if got_output:
            # rescale the packet pts and dts, which are in codec time_base, to the streams time_base
            if packet.ptr.pts != lib.AV_NOPTS_VALUE:
                packet.ptr.pts = lib.av_rescale_q(packet.ptr.pts,
                                                         self._codec_context.time_base,
                                                         self._stream.time_base)
            if packet.ptr.dts != lib.AV_NOPTS_VALUE:
                packet.ptr.dts = lib.av_rescale_q(packet.ptr.dts,
                                                     self._codec_context.time_base,
                                                     self._stream.time_base)

            if packet.ptr.duration != lib.AV_NOPTS_VALUE:
                packet.ptr.duration = lib.av_rescale_q(packet.ptr.duration,
                                                     self._codec_context.time_base,
                                                     self._stream.time_base)

            packet.ptr.stream_index = self._stream.index
            packet.stream = self

            return packet

    @property
    def average_rate(self):
        return avrational_to_fraction(&self._stream.avg_frame_rate)

    @property
    def gop_size(self):
        return self._codec_context.gop_size if self._codec_context else None

    @gop_size.setter
    def gop_size(self, int value):
        self._codec_context.gop_size = value

    @property
    def sample_aspect_ratio(self):
        return avrational_to_fraction(&self._codec_context.sample_aspect_ratio) if self._codec_context else None

    @sample_aspect_ratio.setter
    def sample_aspect_ratio(self, value):
        to_avrational(value, &self._codec_context.sample_aspect_ratio)

    @property
    def  display_aspect_ratio(self):
        cdef lib.AVRational dar

        lib.av_reduce(
            &dar.num, &dar.den,
            self._codec_context.width * self._codec_context.sample_aspect_ratio.num,
            self._codec_context.height * self._codec_context.sample_aspect_ratio.den, 1024*1024)

        return avrational_to_fraction(&dar)

    @property
    def has_b_frames(self):
        if self._codec_context.has_b_frames:
            return True
        return False

    @property
    def coded_width(self):
        return self._codec_context.coded_width if self._codec_context else None

    @property
    def coded_height(self):
        return self._codec_context.coded_height if self._codec_context else None

    @property
    def width(self):
        return self._codec_context.width if self._codec_context else None

    @width.setter
    def width(self, unsigned int value):
        self._codec_context.width = value
        self._build_format()

    @property
    def height(self):
        return self._codec_context.height if self._codec_context else None

    @height.setter
    def height(self, unsigned int value):
        self._codec_context.height = value
        self._build_format()
    # TEMPORARY WRITE-ONLY PROPERTIES to get encoding working again.
    property pix_fmt:
        def __set__(self, value):
            self._codec_context.pix_fmt = lib.av_get_pix_fmt(value)
            self._build_format()
