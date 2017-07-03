
cdef extern from "libavfilter/avfilter.h" nogil:

    cdef int   avfilter_version()
    cdef char* avfilter_configuration()
    cdef char* avfilter_license()

    cdef void avfilter_register_all()

    cdef struct AVFilterPad:
        # This struct is opaque.
        pass

    const char* avfilter_pad_get_name(const AVFilterPad *pads, int index)
    AVMediaType avfilter_pad_get_type(const AVFilterPad *pads, int index)
    int avfilter_pad_count(const AVFilterPad *pads);
    cdef struct AVFilter:

        const AVClass *priv_class

        const const char *name
        const const char *description

        int flags

        const AVFilterPad *inputs
        const AVFilterPad *outputs

        int (*init)(AVFilterContext *ctx)
        int (*init_dict)(AVFilterContext *ctx, AVDictionary **options)
        void (*uninit)(AVFilterContext *ctx)
        int (*query_formats)(AVFilterContext *)

        int priv_size
        int flags_internal
        AVFilter *next
        int (*process_command)(AVFilterContext *, const char *cmd, const char *arg, char *res, int res_len, int flags)
        int (*init_opaque)(AVFilterContext *, void *opaque)
        int (*activate)(AVFilterContext *)

    cdef int AVFILTER_FLAG_DYNAMIC_INPUTS
    cdef int AVFILTER_FLAG_DYNAMIC_OUTPUTS
    cdef int AVFILTER_FLAG_SLICE_THREADS
    cdef int AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC
    cdef int AVFILTER_FLAG_SUPPORT_TIMELINE_INTERNAL

    cdef AVFilter* avfilter_get_by_name(const char *name)
    const AVFilter *avfilter_next(const AVFilter *prev);
    cdef struct AVFilterLink # Defined later.

    cdef struct AVFilterContext:

        const AVClass *av_class
        const AVFilter *filter

        char *name

        AVFilterPad *input_pads
        AVFilterLink **inputs
        unsigned int nb_inputs

        AVFilterPad *output_pads
        AVFilterLink **outputs
        unsigned int nb_outputs

        AVFilterGraph *graph
        int thread_type

        AVBufferRef *hw_device_ctx
        int nb_threasd
        unsigned ready


    cdef int avfilter_init_str(AVFilterContext *ctx, const char *args)
    cdef int avfilter_init_dict(AVFilterContext *ctx, AVDictionary **options)
    cdef void avfilter_free(AVFilterContext*)

    cdef struct AVFilterLink:

        AVFilterContext *src
        AVFilterPad *srcpad
        AVFilterContext *dst
        AVFilterPad *dstpad

        AVMediaType Type
        int w
        int h
        AVRational sample_aspect_ratio
        uint64_t channel_layout
        int sample_rate
        int format
        AVRational time_base
        int request_samples

        AVFilterGraph *graph
        int64_t current_pts
        int64_t curent_pts_us
        int age_index
        AVRational frame_rate
        AVFrame *partial_buf
        int partial_buf_size

        int min_samples
        int max_samples
        int channels
        unsigned flags
        int64_t frame_count_in
        int64_t frame_count_out

        int frame_wanted_out
        AVBufferRef *hw_frames_ctx
#        int64_t frame_count

    cdef int avfilter_link(AVFilterContext *src, unsigned srcpad, AVFilterContext *dst, unsigned dstpad)
    void avfilter_link_free(AVFilterLink **link)
    int avfilter_config_links(AVFilterContext *filter)
    cdef int avfilter_link_get_channels(AVFilterLink *link)
    cdef int avfilter_process_command(AVFilterContext *filter, const char *cmd, const char *arg, int res_len, int flags)

    cdef int avfilter_insert_filter(AVFilterLink *link, AVFilterContext *flt, unsigned filt_srcpad_idx, unsigned flt_dstpad_idx)
    cdef const AVClass *avfilter_get_class()
    cdef int avfilter_register(AVFilter *filter)

