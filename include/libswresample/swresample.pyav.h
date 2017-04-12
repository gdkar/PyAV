// This header serves to smooth out the differences in FFmpeg and LibAV.

#ifdef PYAV_HAVE_LIBSWRESAMPLE

    #include <libswresample/swresample.h>

    // swr does not have the equivalent so this does nothing
    inline void swr_close(SwrContext *ctx) {};

#else

    #include <libavresample/avresample.h>

    #define SwrContext AVAudioResampleContext
    #define swr_init(ctx) avresample_open(ctx)
    #define swr_close(ctx) avresample_close(ctx)
    #define swr_free(ctx) avresample_free(ctx)
    #define swr_alloc() avresample_alloc_context()
    #define swr_get_delay(ctx, ...) avresample_get_delay(ctx)
    #define swr_convert(ctx, out, out_count, in, in_count) \
       avresample_convert((ctx), (out), 0, (out_count), ((uint8_t **)in), 0, (in_count))
    #define swr_set_compensation(ctx,delta,comp)\
       avresample_set_compensation(ctx,delta,comp)
    #define swr_convert_frame((ctx),(out),(in)) \
      avresample_convert_frame((ctx),(out),(in))
    #define swr_config_frame((ctx),(out),(in)) \
      avresample_config((ctx),(out),(in))
    #define swr_get_out_samples(ctx,in_samples)\
      avresample_get_out_samples((ctx),(in_samples))
    #define swr_set_channel_mapping(ctx, map)\
      avresample_set_channel_mapping((ctx),(map))
    #define swr_set_matrix(ctx,matrix,stride) \
      avresample_set_matrix((ctx),(matrix),(stride))
    #define swr_is_initialized(ctx) avresample_is_open(ctx)
    #define swr_drop_output(ctx,count) \
      avresample_read((ctx),NULL,count)
    int swr_inject_silence(AVAudioResampleContext *ctx, int count){
      enum AVSampleFormat in_format;
      int64_t             in_layout;
      int                 in_linesize;
      uint8_t            *input = NULL;
      av_opt_get_channel_layout ( ctx, "in_channel_layout", &in_layout, 0 );
      av_opt_get_sample_fmt     ( ctx, "in_sample_fmt",     &in_format, 0 );
      int in_channels = av_get_channel_layout_nb_channels(in_layout);
      av_samples_alloc(&input, &in_linesize, in_channels, count, in_format );
      int ret = avresample_convert(ctx, NULL, 0, 0, &input, in_linesize, count );
      av_freep(&input);
      return ret;
    }
#endif



#ifndef PYAV_HAVE_LIBAVRESAMPLE
    inline int avresample_version() { return -1; }
    inline const char* avresample_configuration() { return ""; }
    inline const char* avresample_license() { return ""; }
#endif

#ifndef PYAV_HAVE_LIBSWRESAMPLE
    inline int swresample_version() { return -1; }
    inline const char* swresample_configuration() { return ""; }
    inline const char* swresample_license() { return ""; }
#endif
