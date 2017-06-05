
cdef extern from "libavfilter/avfiltergraph.h" nogil:
    
    cdef struct AVFilterGraph:
        AVFilterContext **filters
        int nb_filters
        int thread_type
        int nb_threads



    cdef struct AVFilterInOut:
        char *name
        AVFilterContext *filter_ctx
        int pad_idx
        AVFilterInOut *next


    cdef AVFilterGraph* avfilter_graph_alloc()
    cdef void avfilter_graph_free(AVFilterGraph **ptr)

    cdef int avfilter_graph_parse2(
        AVFilterGraph *graph,
        const char *filter_str,
        AVFilterInOut **inputs,
        AVFilterInOut **outputs
    )

    cdef AVFilterContext* avfilter_graph_alloc_filter(
        AVFilterGraph *graph,
        const AVFilter *filter,
        const char *name
    )
    
    cdef int avfilter_graph_create_filter(
        AVFilterContext **filt_ctx,
        AVFilter *filt,
        const char *name,
        const char *args,
        void *opaque,
        AVFilterGraph *graph_ctx
    )

    cdef int avfilter_link(
        AVFilterContext *src,
        unsigned int srcpad,
        AVFilterContext *dst,
        unsigned int dstpad
    )

    cdef int avfilter_graph_config(AVFilterGraph *graph, void *logctx)

    cdef char* avfilter_graph_dump(AVFilterGraph *graph, const char *options)

    cdef int avfilter_graph_request_oldest(AVFilterGraph *graph)

    cdef void avfilter_inout_free(AVFilterInOut **inout_list)

    cdef int avfilter_graph_send_command(AVFilterGraph *graph, const char *target, const char *cmd, const char *arg, char *res, int res_len, int flags)

    cdef int avfilter_graph_queue_command(AVFilterGraph *graph, const char *target, const char *cmd, const char *arg, int flags, double ts)

