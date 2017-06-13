
# This file is built by setup.py and contains macros telling us which libraries
# and functions we have (of those which are different between FFMpeg and LibAV).
cdef extern from "pyav/config.h" nogil:
    char* PYAV_VERSION_STR
    char* PYAV_COMMIT_STR


include "libavutil/pixfmt.pxd"
include "libavutil/dict.pxd"
include "libavutil/rational.pxd"
include "libavutil/mathematics.pxd"
include "libavutil/avutil.pxd"
include "libavutil/mem.pxd"
include "libavutil/channel_layout.pxd"
include "libavutil/samplefmt.pxd"
include "libavutil/opt.pxd"
include "libavutil/frame.pxd"
include "libavutil/intfloat.pxd"
include "libavutil/buffer.pxd"

include "libavcodec/avcodec.pxd"
include "libavdevice/avdevice.pxd"
include "libavformat/avformat.pxd"
include "libswresample/swresample.pxd"
include "libswscale/swscale.pxd"

include "libavfilter/avfilter.pxd"
include "libavfilter/avfiltergraph.pxd"
include "libavfilter/buffersink.pxd"
include "libavfilter/buffersrc.pxd"


cdef extern from "stdio.h" nogil:

    cdef int snprintf(char *output, size_t n, const char *format, ...)
    cdef int vsnprintf(char *output, size_t  n, const char *format, va_list args)
#include "libavfilter/avfilter.pxd"
#include "libavfilter/buffersrc.pxd"
#include "libavfilter/buffersink.pxd"
