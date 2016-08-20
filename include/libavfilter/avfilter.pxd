
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

        AVClass *priv_class

        const char *name
        const char *description

        const int flags
        
        const AVFilterPad *inputs
        const AVFilterPad *outputs

        AVFilter *next

    cdef int AVFILTER_FLAG_DYNAMIC_INPUTS
    cdef int AVFILTER_FLAG_DYNAMIC_OUTPUTS
    cdef int AVFILTER_FLAG_SLICE_THREADS
    cdef int AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC
    cdef int AVFILTER_FLAG_SUPPORT_TIMELINE_INTERNAL

    cdef AVFilter* avfilter_get_by_name(const char *name)

    cdef struct AVFilterLink # Defined later.
    
    cdef struct AVFilterContext:

        AVClass *av_class
        AVFilter *filter

        char *name

        AVFilterPad *input_pads
        AVFilterLink **inputs
        unsigned int nb_inputs
        
        AVFilterPad *output_pads
        AVFilterLink **outputs
        unsigned int nb_outputs


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
        int64_t current_pts
        int64_t curent_pts_us
        int age_index
        AVRational frame_rate
        int min_samples
        int max_samples
        int channels
        int flags
        int64_t frame_count
        
    cdef int avfilter_link_get_channels(AVFilterLink *link)
    cdef int avfilter_process_command(AVFilterContext *filter, const char *cmd, const char *arg, int res_len, flags)

    cdef int avfilter_insert_filter(AVFilterLink *link, AVFilterContext *flt, unsigned filt_srcpad_idx, unsigned flt_dstpad_idx)

