from libc.stdint cimport uint8_t, int64_t
from libc.string cimport memcpy
from cpython cimport PyWeakref_NewRef

cimport libav as lib

from av.audio.stream cimport AudioStream
from av.packet cimport Packet
from av.frame cimport Frame
from av.subtitles.stream cimport SubtitleStream
from av.utils cimport err_check, avdict_to_dict, avrational_to_fraction, to_avrational, media_type_to_string
from av.video.stream cimport VideoStream

cdef object _cinit_bypass_sentinel = object()

cdef Stream build_stream(Container container, lib.AVStream *c_stream):
    """Build an av.Stream for an existing AVStream.

    The AVStream MUST be fully constructed and ready for use before this is
    called.

    """
    # This better be the right one...
    assert container.proxy.ptr.streams[c_stream.index] == c_stream
    cdef Stream py_stream
    if c_stream.codec.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        py_stream = VideoStream.__new__(VideoStream, _cinit_bypass_sentinel)
    elif c_stream.codec.codec_type == lib.AVMEDIA_TYPE_AUDIO:
        py_stream = AudioStream.__new__(AudioStream, _cinit_bypass_sentinel)
    elif c_stream.codec.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
        py_stream = SubtitleStream.__new__(SubtitleStream, _cinit_bypass_sentinel)
    else:
        py_stream = Stream.__new__(Stream, _cinit_bypass_sentinel)
    py_stream._init(container, c_stream)
    return py_stream

cdef class Stream:
    def __cinit__(self, name):
        self._codec_options = _Dictionary()
        if name is _cinit_bypass_sentinel:return
        raise RuntimeError('cannot manually instatiate Stream')
    cdef _init(self, Container container, lib.AVStream *stream):

        self._container      = container.proxy
        self._weak_container = PyWeakref_NewRef(container, None)
        self._stream         = stream
        self._codec_context  = stream.codec
        self.metadata        = avdict_to_dict(stream.metadata)
        cdef int err = 0
        # This is an input container!
        if self._container.ptr.iformat:
            # Find the codec.
            self._codec = lib.avcodec_find_decoder(self._codec_context.codec_id)
            if self._codec == NULL:
                return
            # Open the codec.
            try:
                with nogil:
                    err = lib.avcodec_open2(self._codec_context, self._codec, &self._codec_options.ptr)
                err_check(err)
            except:
                # Signal that we don't need to close it.
                self._codec = NULL
                raise
        # This is an output container!
        else:
            self._codec = self._codec_context.codec
    def __dealloc__(self):
        if self._codec:
            lib.avcodec_close(self._codec_context)
    def __repr__(self):
        return '<av.%s #%d %s/%s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.type or '<notype>',
            self.name or '<nocodec>',
            id(self),
        )
    @property
    def discard(self):
        return self._stream.discard

    @discard.setter
    def discard(self,x):
        if x == 'none': self._stream.discard = lib.AVDISCARD_NONE
        elif x == 'default':self._stream.discard = lib.AVDISCARD_DEFAULT
        elif x == 'nonref':self._stream.discard = lib.AVDISCARD_NONREF
        elif x == 'bidir':self._stream.discard = lib.AVDISCARD_BIDIR
        elif x == 'nonintra':self._stream.discard = lib.AVDISCARD_NONINTRA
        elif x == 'nonkey':self._stream.discard = lib.AVDISCARD_NONKEY
        elif x == 'all':self._stream.discard = lib.AVDISCARD_ALL
        elif x in (-16,0,8,16,24,32,48):
            self._stream.discard = x


    @property
    def id(self):
        return self._stream.id

    @id.setter
    def id(self, v):
        if v is None:
            self._stream.id = 0
        else:
            self._stream.id = v

    @property
    def type(self):
        return media_type_to_string(self._codec_context.codec_type)

    @property
    def name(self):
        return self._codec.name if self._codec else None

    @property
    def long_name(self):
        return self._codec.long_name if self._codec else None

    @property
    def profile(self):
        if self._codec and lib.av_get_profile_name(self._codec, self._codec_context.profile):
            return lib.av_get_profile_name(self._codec, self._codec_context.profile)
        else:return None

    @property
    def index(self):
        return self._stream.index
    @property
    def time_base(self):
        return avrational_to_fraction(&self._stream.time_base)
    @property
    def rate(self):
        if self._codec_context:
            return self._codec_context.ticks_per_frame * avrational_to_fraction(&self._codec_context.time_base)
    @property
    def average_rate(self):
        return avrational_to_fraction(&self._stream.avg_frame_rate)
    @property
    def start_time(self):
        return self._stream.start_time
    @property
    def duration(self):
        if self._stream.duration == lib.AV_NOPTS_VALUE: return None
        return self._stream.duration
    @property
    def frames(self):
        return self._stream.nb_frames
    @property
    def bit_rate(self):
        return self._codec_context.bit_rate if self._codec_context and self._codec_context.bit_rate > 0 else None

    @bit_rate.setter
    def bit_rate(self, int value):
        self._codec_context.bit_rate = value

    @property
    def max_bit_rate(self):
        if self._codec_context and self._codec_context.rc_max_rate > 0:
            return self._codec_context.rc_max_rate
        else:
            return None
    @property
    def bit_rate_tolerance(self):
        return self._codec_context.bit_rate_tolerance if self._codec_context else None

    @bit_rate_tolerance.setter
    def bit_rate_tolerance(self, int value):
        self._codec_context.bit_rate_tolerance = value

    @property
    def language(self):
        return self.metadata.get('language')

    # TODO: Does it conceptually make sense that this is on streams, instead
    # of on the container?
    @property
    def thread_count(self):
        return self._codec_context.thread_count

    @thread_count.setter
    def thread_count(self, int value):
        self._codec_context.thread_count = value

    cpdef decode(self, Packet packet, int count=0):
        """Decode a list of :class:`.Frame` from the given :class:`.Packet`.

        If the packet is None, the buffers will be flushed. This is useful if
        you do not want the library to automatically re-order frames for you
        (if they are encoded with a codec that has B-frames).

        """
        if packet is None:
            packet = Packet()
#            raise TypeError('packet must not be None')
        if not self._codec:
            raise ValueError('cannot decode unknown codec')

        cdef int data_consumed = 0
        cdef list decoded_objs = []

        cdef uint8_t *original_data = packet.ptr.data
        cdef int      original_size = packet.ptr.size

        cdef bint is_flushing = not (packet.ptr.data and packet.ptr.size)
        cdef int err = 0
        cdef lib.AVPacket *pkt = packet.ptr

        # Keep decoding while there is data.
        while is_flushing or packet.ptr.size > 0:
            if is_flushing and packet is not None:
                packet.ptr.data = NULL
                packet.ptr.size = 0
            decoded = self._decode_one(pkt, &data_consumed)
            if packet.ptr:
                packet.ptr.data += data_consumed
                packet.ptr.size -= data_consumed
            if decoded:
                if isinstance(decoded, Frame):
                    self._setup_frame(decoded)
                decoded_objs.append(decoded)

                # Sometimes we will error if we try to flush the stream
                # (e.g. MJPEG webcam streams), and so we must be able to
                # bail after the first, even though buffers may build up.
                if count and len(decoded_objs) >= count:
                    break
            # Sometimes there are no frames, and no data is consumed, and this
            # is ok. However, no more frames are going to be pulled out of here.
            # (It is possible for data to not be consumed as long as there are
            # frames, e.g. during flushing.)
            elif not data_consumed:
                break
        # Restore the packet.
        packet.ptr.data = original_data
        packet.ptr.size = original_size
        return decoded_objs

    def seek(self, timestamp, mode='time', backward=True, any_frame=False):
        """
        Seek to the keyframe at timestamp.
        """
        if isinstance(timestamp, float):
            self._container.seek(-1, <long>(timestamp * lib.AV_TIME_BASE), mode, backward, any_frame)
        else:
            self._container.seek(self._stream.index, <long>timestamp, mode, backward, any_frame)
    cdef _setup_frame(self, Frame frame):
        # This PTS handling looks a little nuts, however it really seems like it
        # is the way to go. The PTS from a packet is the correct one while
        # decoding, and it is copied to pkt_pts during creation of a frame.
        frame.ptr.pts = frame.ptr.pkt_pts
        frame._time_base = self._stream.time_base
        frame.index = self._codec_context.frame_number - 1
    cdef Frame _alloc_frame(self):
        raise NotImplementedError('base stream cannot decode packets')

    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        cdef int completed_frame = 0
        cdef int err
        cdef Frame frame = self._alloc_frame()
        with nogil:
            err = lib.avcodec_receive_frame(self._codec_context, frame.ptr)
            if err < 0:
                if err == lib.AVERROR_EOF:
                    lib.avcodec_flush_buffers(self._codec_context)
                elif err != lib.AVERROR(lib.EAGAIN):
                    with gil:
                        err_check(err)
            else:
                completed_frame = 1
        if packet:
            with nogil:
                err = lib.avcodec_send_packet(self._codec_context, packet)
            if err == 0:
                data_consumed[0] = packet.size
            else:
                data_consumed[0] = 0
#            data_consumed[0] = err < 0
#        data_consumed[0] = err_check(lib.avcodec_decode_audio4(self._codec_context, self.next_frame.ptr, &completed_frame, packet))
        if not completed_frame:
            return
        frame.ptr.pts = lib.av_frame_get_best_effort_timestamp ( frame.ptr )
        frame.ptr.pts = lib.av_rescale_q(
            frame.ptr.pts
          , self._codec_context.time_base
          , self._stream.time_base
            )
        frame._time_base = self._codec_context.time_base
        frame._init_properties()
        return frame
