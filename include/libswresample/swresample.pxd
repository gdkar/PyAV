from libc.stdint cimport int64_t, uint8_t

cdef extern from "libswresample/swresample.pyav.h" nogil:

    cdef int   avresample_version()
    cdef char* avresample_configuration()
    cdef char* avresample_license()

    cdef int   swresample_version()
    cdef char* swresample_configuration()
    cdef char* swresample_license()


    cdef struct SwrContext:
        pass
    cdef enum SwrEngine:
        SWR_ENGINE_SWR  = 0
        SWR_ENGINE_SOXR = 1
        SWR_ENGINE_NB   = 2
    cdef enum SwwrFilterType:
        SWR_FILTER_TYPE_CUBIC = 0
        SWR_FILTER_TYPE_BLACKMAN_NUTTALL = 1
        SWR_FILTER_TYPE_KAISER = 2
    cdef const int SWR_CH_MAX
    cdef SwrContext* swr_alloc_set_opts(
        SwrContext *ctx,
        int64_t out_ch_layout,
        AVSampleFormat out_sample_fmt,
        int out_sample_rate,
        int64_t in_ch_layout,
        AVSampleFormat in_sample_fmt,
        int in_sample_rate,
        int log_offset,
        void *log_ctx #logging context, can be NULL
    )

    cdef int swr_convert(
        SwrContext *ctx,
        uint8_t ** out_buffer,
        int out_count,
        uint8_t **in_buffer,
        int in_count
    )
    cdef int swr_convert_frame(
            SwrContext *ctx,
            AVFrame *_output,
            const AVFrame *_input
            )
    cdef int swr_config_frame(
            SwrContext *swr,
            const AVFrame *_output,
            const AVFrame *_input
            )
    cdef int swr_get_out_samples(SwrContext *s, int in_samples)
    # Gets the delay the next input sample will
    # experience relative to the next output sample.
    cdef int64_t swr_next_pts(SwrContext *s, int64_t pts)
    cdef int swr_set_compensation(SwrContext *s, int sample_delta, int compensation_distance)
    cdef int swr_set_channel_mapping(SwrContext *s, const int *channel_map)
    cdef int swr_set_matrix(SwrContext *s, const double *matrix, int stride)
    cdef int swr_drop_output(SwrContext *s, int count)
    cdef int swr_inject_silence(SwrContext *s, int count)
    cdef int64_t swr_get_delay(SwrContext *s, int64_t base)

    cdef SwrContext* swr_alloc()
    cdef SwrContext* swr_alloc_set_opts(SwrContext *s,
            int64_t out_ch_layout,
            AVSampleFormat out_sample_fmt,
            int out_sample_rate,
            int64_t in_ch_layout,
            AVSampleFormat in_sample_fmt,
            int in_sample_rate,
            int log_offset,
            void *log_ctx
            )
    cdef int swr_init(SwrContext* ctx)
    cdef int swr_is_initialized(SwrContext *ctx)
    cdef void swr_free(SwrContext **ctx)

    # wrapper for libavresample
    cdef void swr_close(SwrContext *ctx)

