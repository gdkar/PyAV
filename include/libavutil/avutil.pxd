from libc.stdint cimport int64_t, uint8_t, uint64_t


cdef extern from "libavutil/mathematics.h" nogil:
    pass

cdef extern from "libavutil/rational.h" nogil:
    cdef int av_reduce(int *dst_num, int *dst_den, int64_t num, int64_t den, int64_t max)

cdef extern from "libavutil/avutil.pyav.h" nogil:

    cdef int   avutil_version()
    cdef char* avutil_configuration()
    cdef char* avutil_license()

    cdef enum AVPixelFormat:
        AV_PIX_FMT_NONE
        AV_PIX_FMT_YUV420P
        AV_PIX_FMT_RGB24
        PIX_FMT_RGB24
        PIX_FMT_RGBA

    cdef enum AVSampleFormat:
        AV_SAMPLE_FMT_NONE
        AV_SAMPLE_FMT_S16
        AV_SAMPLE_FMT_FLTP

    cdef enum AVRounding:
        AV_ROUND_ZERO
        AV_ROUND_INF
        AV_ROUND_DOWN
        AV_ROUND_UP
        AV_ROUND_NEAR_INF
        # This is nice, but only in FFMpeg:
        # AV_ROUND_PASS_MINMAX

    cdef int AV_ERROR_MAX_STRING_SIZE
    cdef int AVERROR_EOF
    cdef int AVERROR_NOMEM "AVERROR(ENOMEM)"

    cdef int AV_CH_LAYOUT_STEREO

    cdef int ENOMEM

    cdef int EAGAIN

    cdef double M_PI

    cdef int AVERROR(int error)
    cdef int av_strerror(int errno, char *output, size_t output_size)
    cdef char* av_err2str(int errnum)

    cdef void* av_malloc(size_t size)
    cdef void *av_calloc(size_t nmemb, size_t size)

    cdef void av_free(void* ptr)
    cdef void av_freep(void *ptr)

    cdef int av_get_bytes_per_sample(AVSampleFormat sample_fmt)

    cdef int av_samples_get_buffer_size(
        int *linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )

    # See: http://ffmpeg.org/doxygen/trunk/structAVRational.html
    ctypedef struct AVRational:
        int num
        int den

    cdef AVRational AV_TIME_BASE_Q

    # Rescales from one time base to another
    cdef int64_t av_rescale_q(
        int64_t a, # time stamp
        AVRational bq, # source time base
        AVRational cq  # target time base
    )

    # Rescale a 64-bit integer with specified rounding.
    # A simple a*b/c isn't possible as it can overflow
    cdef int64_t av_rescale_rnd(
        int64_t a,
        int64_t b,
        int64_t c,
        int r # should be AVRounding, but then we can't use bitwise logic.
    )

    cdef int64_t av_rescale_q_rnd(
        int64_t a,
        AVRational bq,
        AVRational cq,
        int r # should be AVRounding, but then we can't use bitwise logic.
    )

    cdef int64_t av_rescale(
        int64_t a,
        int64_t b,
        int64_t c
    )

    cdef char* av_strdup(char *s)

    cdef int av_opt_set_int(
        void *obj,
        char *name,
        int64_t value,
        int search_flags
    )
    cdef int av_opt_set(void * obj,const char *name,const char *val, int search_flags)
    cdef int av_opt_set_double(void * obj,const char *name,double val, int search_flags)
    cdef int av_opt_set_q(void * obj,const char *name,AVRational val, int search_flags)
    cdef int av_opt_set_bin(void * obj,const char *name,const uint8_t *val, int search_flags)
    cdef int av_opt_set_channel_layout(void * obj,const char *name,int64_t ch_layout, int search_flags)
    cdef int av_opt_set_sample_fmt(void * obj,const char *name,AVSampleFormat fmt, int search_flags)
    cdef int av_opt_set_pixel_fmt(void * obj,const char *name,AVPixelFormat fmt, int search_flags)
    cdef int av_opt_set_dict_val(void *obj, const char *name, const AVDictionary *val, int search_flags)
    cdef int av_opt_get(void *obj, const char *name, int search_flags, uint8_t **out_val)
    cdef int av_opt_get_int(void *obj, const char *name, int search_flags, int64_t *out_val)
    cdef int av_opt_get_double(void *obj, const char *name, int search_flags, double *out_val)
    cdef int av_opt_get_q(void *obj, const char *name, int search_flags, AVRational *out_val)
cdef extern from "libavutil/pixdesc.h" nogil:


    # See: http://ffmpeg.org/doxygen/trunk/structAVComponentDescriptor.html
    cdef struct AVComponentDescriptor:
        # These are bitfields, but this should generate the right C anyways.
        unsigned int plane
        unsigned int step_minus1
        unsigned int offset_plus1
        unsigned int shift
        unsigned int depth_minus1

    cdef enum AVPixFmtFlags:
        AV_PIX_FMT_FLAG_BE
        AV_PIX_FMT_FLAG_PAL
        AV_PIX_FMT_FLAG_BITSTREAM
        AV_PIX_FMT_FLAG_HWACCEL
        AV_PIX_FMT_FLAG_PLANAR
        AV_PIX_FMT_FLAG_RGB

    # See: http://ffmpeg.org/doxygen/trunk/structAVPixFmtDescriptor.html
    cdef struct AVPixFmtDescriptor:
        const char *name
        uint8_t nb_components
        uint8_t log2_chroma_w
        uint8_t log2_chroma_h
        uint8_t flags
        AVComponentDescriptor comp[4]

    cdef AVPixFmtDescriptor* av_pix_fmt_desc_get(AVPixelFormat pix_fmt)
    cdef AVPixFmtDescriptor* av_pix_fmt_desc_next(AVPixFmtDescriptor *prev)

    cdef char * av_get_pix_fmt_name(AVPixelFormat pix_fmt)
    cdef AVPixelFormat av_get_pix_fmt(char* name)




cdef extern from "libavutil/channel_layout.h" nogil:

    # Layouts.
    cdef uint64_t av_get_channel_layout(char* name)
    cdef int av_get_channel_layout_nb_channels(uint64_t channel_layout)
    cdef int64_t av_get_default_channel_layout(int nb_channels)
    cdef void av_get_channel_layout_string(
        char* buff,
        int buf_size,
        int nb_channels,
        uint64_t channel_layout
    )

    # Channels.
    cdef uint64_t av_channel_layout_extract_channel(uint64_t layout, int index)
    cdef char* av_get_channel_name(uint64_t channel)
    cdef char* av_get_channel_description(uint64_t channel)

    
cdef extern from "libavutil/fifo.h" nogil:
    ctypedef struct AVFifoBuffer:
        uint8_t *buffer
        uint8_t *rptr
        uint8_t *wptr
        uint8_t *end
        unsigned int rndx
        unsigned int wndx
    
    cdef AVFifoBuffer *av_fifo_alloc(unsigned int size)
    cdef AVFifoBuffer *av_fifo_alloc_array(size_t nmemb, size_t size)
    cdef void av_fifo_free(AVFifoBuffer *f)
    cdef void av_fifo_freep(AVFifoBuffer **f)
    cdef void av_fifo_reset(AVFifoBuffer *f)
    cdef int  av_fifo_size(const AVFifoBuffer *f)
    cdef int  av_fifo_space(const AVFifoBuffer *f)
    cdef int  av_fifo_generic_read(AVFifoBuffer *f, void *dest, int buf_size, void (*func)(void*,void*,int))
    cdef int  av_fifo_generic_write(AVFifoBuffer *f, void *dest, int buf_size, void (*func)(void*,void*,int))
    cdef int  av_fifo_realloc(AVFifoBuffer *f, unsigned int size)
    cdef int  av_fifo_grow(AVFifoBuffer *f, unsigned int additional_space)
    cdef void av_fifo_drain(AVFifoBuffer *f, int size)
cdef inline uint8_t *av_fifo_peek2(const AVFifoBuffer *f, int offs):
    cdef uint8_t *ptr = f.rptr + offs
    if ptr >= f.end:
        ptr = f.buffer + (ptr-f.end)
    elif ptr < f.buffer:
        ptr = f.end - (f.buffer-ptr)
    return ptr
cdef extern from "libavutil/audio_fifo.h" nogil:

    cdef struct AVAudioFifo:
        AVFifoBuffer **buf
        int            nb_buffers
        int            nb_samples
        int            allocated_samples
        int            channels
        AVSampleFormat sample_fmt
        int            sample_size
    
    cdef void av_audio_fifo_free(AVAudioFifo *af)

    cdef AVAudioFifo* av_audio_fifo_alloc(
         AVSampleFormat sample_fmt,
         int channels,
         int nb_samples
    )

    cdef int av_audio_fifo_write(
        AVAudioFifo *af,
        void **data,
        int nb_samples
    )

    cdef int av_audio_fifo_read(
        AVAudioFifo *af,
        void **data,
        int nb_samples
    )

    cdef int av_audio_fifo_size(AVAudioFifo *af)
    cdef int av_audio_fifo_space (AVAudioFifo *af)


cdef extern from "stdarg.h" nogil:

    # For logging. Should really be in another PXD.
    ctypedef struct va_list:
        pass


cdef extern from "Python.h" nogil:

    # For logging. See av/logging.pyx for an explanation.
    cdef int Py_AddPendingCall(void *, void *)
    void PyErr_PrintEx(int set_sys_last_vars)
    int Py_IsInitialized()
    void PyErr_Display(object, object, object)


cdef extern from "libavutil/opt.h" nogil:

    cdef enum AVOptionType:

        AV_OPT_TYPE_FLAGS
        AV_OPT_TYPE_INT
        AV_OPT_TYPE_INT64
        AV_OPT_TYPE_DOUBLE
        AV_OPT_TYPE_FLOAT
        AV_OPT_TYPE_STRING
        AV_OPT_TYPE_RATIONAL
        AV_OPT_TYPE_BINARY
        #AV_OPT_TYPE_DICT # Missing from FFmpeg
        AV_OPT_TYPE_CONST
        #AV_OPT_TYPE_IMAGE_SIZE # Missing from LibAV
        #AV_OPT_TYPE_PIXEL_FMT # Missing from LibAV
        #AV_OPT_TYPE_SAMPLE_FMT # Missing from LibAV
        #AV_OPT_TYPE_VIDEO_RATE # Missing from FFmpeg
        #AV_OPT_TYPE_DURATION # Missing from FFmpeg
        #AV_OPT_TYPE_COLOR # Missing from FFmpeg
        #AV_OPT_TYPE_CHANNEL_LAYOUT # Missing from FFmpeg

    cdef struct AVOption_default_val:
        int64_t i64
        double dbl
        const char *str
        AVRational q

    cdef struct AVOption:

        const char *name
        const char *help
        AVOptionType type
        int offset

        AVOption_default_val default_val

        double min
        double max
        int flags
        const char *unit
    cdef AVOption *av_opt_find(void *, const char*, const char*, int, int)

cdef extern from "libavutil/log.h" nogil:

    cdef enum AVClassCategory:
        AV_CLASS_CATEGORY_NA
        AV_CLASS_CATEGORY_INPUT
        AV_CLASS_CATEGORY_OUTPUT
        AV_CLASS_CATEGORY_MUXER
        AV_CLASS_CATEGORY_DEMUXER
        AV_CLASS_CATEGORY_ENCODER
        AV_CLASS_CATEGORY_DECODER
        AV_CLASS_CATEGORY_FILTER
        AV_CLASS_CATEGORY_BITSTREAM_FILTER
        AV_CLASS_CATEGORY_SWSCALER
        AV_CLASS_CATEGORY_SWRESAMPLER
        AV_CLASS_CATEGORY_NB

    cdef struct AVClass:

        const char *class_name
        const char *(*item_name)(void*) nogil

        AVClassCategory category
        int parent_log_context_offset

        AVOption *option

    int AV_LOG_QUIET
    int AV_LOG_PANIC
    int AV_LOG_FATAL
    int AV_LOG_ERROR
    int AV_LOG_WARNING
    int AV_LOG_INFO
    int AV_LOG_VERBOSE
    int AV_LOG_DEBUG

    # Send a log.
    void av_log(void *ptr, int level, const char *fmt, ...)

    # Get the logs.
    ctypedef void(*av_log_callback)(void *, int, const char *, va_list)
    void av_log_set_callback (av_log_callback callback)
