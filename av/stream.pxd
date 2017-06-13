from libc.stdint cimport int64_t

cimport libav as lib
from av.dictionary cimport _Dictionary
from av.dictionary import Dictionary
from av.container.core cimport Container, ContainerProxy
from av.frame cimport Frame
from av.packet cimport Packet


cdef class Stream:
    cdef object __weakref__
    # Stream attributes.
    cdef ContainerProxy _container
    cdef                _weak_container

    cdef lib.AVStream *_stream
    cdef readonly dict metadata

    # CodecContext attributes.
    cdef lib.AVCodecContext *_codec_context
    cdef const lib.AVCodec  *_codec
    cdef readonly _Dictionary         _codec_options

    # Private API.
    cdef _init(self, Container, lib.AVStream*)
    cdef Frame _alloc_frame(self)
    cdef _setup_frame(self, Frame)
    cdef _decode_one(self, lib.AVPacket*, int *data_consumed)

    # Public API.
    cpdef decode(self, Packet packet, int count=?)

cdef Stream build_stream(Container, lib.AVStream*)
