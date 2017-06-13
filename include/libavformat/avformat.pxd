from libc.stdint cimport int64_t, uint64_t


cdef extern from "libavformat/avformat.pyav.h" nogil:

    cdef enum AVDiscard:
        pass
    cdef int   avformat_version()
    cdef char* avformat_configuration()
    cdef char* avformat_license()

    cdef int64_t INT64_MIN

    cdef int AV_TIME_BASE
    cdef int AVSEEK_FLAG_BACKWARD
    cdef int AVSEEK_FLAG_BYTE
    cdef int AVSEEK_FLAG_ANY
    cdef int AVSEEK_FLAG_FRAME


    cdef int AVIO_FLAG_WRITE

    #: Initialize all formats.
    cdef void av_register_all()

    #: Initialize network use in formats.
    cdef void avformat_network_init()

    cdef enum AVMediaType:
        AVMEDIA_TYPE_UNKNOWN
        AVMEDIA_TYPE_VIDEO
        AVMEDIA_TYPE_AUDIO
        AVMEDIA_TYPE_DATA
        AVMEDIA_TYPE_SUBTITLE
        AVMEDIA_TYPE_ATTACHMENT
        AVMEDIA_TYPE_NB
    ctypedef struct AVIOInterruptCB:
        int (*callback)(void*)
        void *opaque
    cdef enum AVIODataMarkerType:
        AVIO_DATA_MARKER_HEADER
        AVIO_DATA_MARKER_SYNC_POINT
        AVIO_DATA_MARKER_BOUNDARY_POINT
        AVIO_DATA_MARKER_UNKNOWN
        AVIO_DATA_MARKER_TRAILER
    ctypedef struct AVFrac:
        int64_t val
        int64_t num
        int64_t den
    ctypedef struct AVProbeData:
        const char *filename
        unsigned char *buf
        int buf_size
        const char *mime_type

    cdef enum AVStreamParseType:
        AVSTREAM_PARSE_NONE
        AVSTREAM_PARSE_FULL
        AVSTREAM_PARSE_HEADERS
        AVSTREAM_PARSE_TIMESTAMPS
        AVSTREAM_PARSE_FULL_ONCE
        AVSTREAM_PARSE_FULL_RAW
    cdef enum AVPacketSideDataType:
        pass
    ctypedef struct AVPacketSideData:
        uint8_t *data
        int      size
        AVPacketSideDataType type

    ctypedef struct AVStream:

        int index
        int id
        void *priv_data

        AVCodecContext *codec

#        AVFrac pts
        AVRational time_base

        int64_t start_time
        int64_t duration
        int64_t nb_frames
        int disposition
        AVDiscard discard
        AVRational sample_aspect_ratio

        AVDictionary *metadata
        AVRational avg_frame_rate
        AVPacket attached_pic
        AVPacketSideData *side_data
        int               nb_side_data
        int event_flags
        int64_t first_dts
        int64_t cur_dts
        int last_IP_pts
        int probe_packets
        int codec_info_nb_framesa
        AVStreamParseType need_parsing
        AVCodecParserContext *parser

        int stream_identifier
        int64_t interleaver_chunk_size
        int64_t interleaver_chunk_duration

        int request_probe
        int skip_to_keyframe
        int skip_samples

        int64_t start_skip_samples
        int64_t first_discard_sample
        int64_t last_discard_sample

        int nb_decoded_frames

        int64_t mux_ts_offset
        int64_t pts_wrap_reference

        int pts_wrap_behavior

        int update_initial_durations_done

        AVCodecParameters *codecpar

    ctypedef struct AVIOContext:
        const AVClass *av_class
        unsigned char* buffer
        int            buffer_size
        unsigned char *buf_ptr
        unsigned char *buf_end
        void          *opaque
        int (*read_packet)(void*opaque,uint8_t*buf,int buf_size)
        int (*write_packet)(void*opaque,uint8_t*buf,int buf_size)
        int64_t (*seek)(void *opaque, int64_t offset, int whence)
        int64_t pos
        int must_flush
        int eof_reached
        int write_flag
        int max_packet_size
        unsigned long checksum
        unsigned char *checksum_ptr
        unsigned long (*update_checksum)(unsigned long checksum, const uint8_t*buf, unsigned int size)
        int error
        int (*read_pause)(void *opaque, int pause)
        int seekable
        int64_t maxsize
        int direct
        int64_t bytes_read
        int seek_count
        int write_count
        int orig_buffer_size
        int short_seek_threshold
        const char *protocol_whitelist
        int (*write_dataa_type)(void *opaque, uint8_t *buf, int buf_size, AVIODataMarkerType type, uint64_t time)
        int ignore_boundary_point
        AVIODataMarkerType current_type
        int64_t last_time
        int (*short_seek_get)(void *opaque)

    # http://ffmpeg.org/doxygen/trunk/structAVIOContext.html

    cdef int AVIO_FLAG_DIRECT
    cdef int AVIO_SEEKABLE_NORMAL

    cdef int SEEK_SET
    cdef int SEEK_CUR
    cdef int SEEK_END
    cdef int AVSEEK_SIZE

    cdef AVIOContext* avio_alloc_context(
        unsigned char *buffer,
        int buffer_size,
        int write_flag,
        void *opaque,
        int(*read_packet)(void *opaque, uint8_t *buf, int buf_size),
        int(*write_packet)(void *opaque, uint8_t *buf, int buf_size),
        int64_t(*seek)(void *opaque, int64_t offset, int whence)
    )

    # http://ffmpeg.org/doxygen/trunk/structAVInputFormat.html
    ctypedef struct AVInputFormat:
        const char *name
        const char *long_name
        const char *extensions
        int flags
        # const AVCodecTag* const *codec_tag
        const AVClass *priv_class

    ctypedef struct AVProbeData:
        unsigned char *buf
        int buf_size
        const char *filename

    cdef AVInputFormat* av_probe_input_format(
        AVProbeData *pd,
        int is_opened
    )

    # http://ffmpeg.org/doxygen/trunk/structAVOutputFormat.html
    ctypedef struct AVOutputFormat:
        const char *name
        const char *long_name
        const char *extensions
        AVCodecID video_codec
        AVCodecID audio_codec
        AVCodecID subtitle_codec
        int flags
        # const AVCodecTag* const *codec_tag
        const AVClass *priv_class

    cdef int AVFMT_NOFILE
    cdef int AVFMT_NEEDNUMBER
    cdef int AVFMT_RAWPICTURE
    cdef int AVFMT_GLOBALHEADER
    cdef int AVFMT_NOTIMESTAMPS
    cdef int AVFMT_VARIABLE_FPS
    cdef int AVFMT_NODIMENSIONS
    cdef int AVFMT_NOSTREAMS
    cdef int AVFMT_ALLOW_FLUSH
    cdef int AVFMT_TS_NONSTRICT
    cdef int AVFMT_FLAG_CUSTOM_IO
    cdef int AVFMT_FLAG_GENPTS

    cdef int av_probe_input_buffer(
        AVIOContext *pb,
        AVInputFormat **fmt,
        const char *filename,
        void *logctx,
        unsigned int offset,
        unsigned int max_probe_size
    )

    cdef AVInputFormat* av_find_input_format(const char *name)
    cdef AVInputFormat* av_iformat_next(AVInputFormat*)
    cdef AVOutputFormat* av_oformat_next(AVOutputFormat*)

    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
    ctypedef struct AVFormatContext:

        # Streams.
        unsigned int nb_streams
        AVStream **streams

        AVInputFormat *iformat
        AVOutputFormat *oformat

        AVIOContext *pb

        AVDictionary *metadata

        char filename
        int64_t start_time
        int64_t duration
        int bit_rate

        int flags
        int64_t max_analyze_duration


    cdef AVFormatContext* avformat_alloc_context()

    # .. c:function:: avformat_open_input(...)
    #
    #       Options are passed via :func:`av.open`.
    #
    #       .. seealso:: FFmpeg's docs: :ffmpeg:`avformat_open_input`
    #
    cdef int avformat_open_input(
        AVFormatContext **ctx, # NULL will allocate for you.
        char *filename,
        AVInputFormat *format, # Can be NULL.
        AVDictionary **options # Can be NULL.
    )

    cdef int avformat_close_input(AVFormatContext **ctx)

    # .. c:function:: avformat_write_header(...)
    #
    #       Options are passed via :func:`av.open`; called in
    #       :meth:`av.container.OutputContainer.start_encoding`.
    #
    #       .. seealso:: FFmpeg's docs: :ffmpeg:`avformat_write_header`
    #
    cdef int avformat_write_header(
        AVFormatContext *ctx,
        AVDictionary **options # Can be NULL
    )

    cdef int av_write_trailer(AVFormatContext *ctx)

    cdef int av_interleaved_write_frame(
        AVFormatContext *ctx,
        AVPacket *pkt
    )

    cdef int av_write_frame(
        AVFormatContext *ctx,
        AVPacket *pkt
    )

    cdef int avio_open(
        AVIOContext **s,
        char *url,
        int flags
    )

    cdef int64_t avio_size(
        AVIOContext *s
    )

    cdef AVOutputFormat* av_guess_format(
        char *short_name,
        char *filename,
        char *mime_type
    )

    cdef int avformat_query_codec(
        AVOutputFormat *ofmt,
        AVCodecID codec_id,
        int std_compliance
    )

    cdef int avio_close(AVIOContext *s)

    cdef int avio_closep(AVIOContext **s)

    cdef int avformat_find_stream_info(
        AVFormatContext *ctx,
        AVDictionary **options, # Can be NULL.
    )

    cdef AVStream* avformat_new_stream(
        AVFormatContext *ctx,
        AVCodec *c
    )

    cdef int avformat_alloc_output_context2(
        AVFormatContext **ctx,
        AVOutputFormat *oformat,
        char *format_name,
        char *filename
    )

    cdef int avformat_free_context(AVFormatContext *ctx)

    cdef void av_dump_format(
        AVFormatContext *ctx,
        int index,
        char *url,
        int is_output,
    )

    cdef int av_read_frame(
        AVFormatContext *ctx,
        AVPacket *packet,
    )

    cdef int av_seek_frame(
        AVFormatContext *ctx,
        int stream_index,
        int64_t timestamp,
        int flags
    )

    cdef int avformat_seek_file(
        AVFormatContext *ctx,
        int stream_index,
        int64_t min_ts,
        int64_t ts,
        int64_t max_ts,
        int flags
    )



