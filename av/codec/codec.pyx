cimport libav as lib
from libc.stdint cimport uint64_t

from warnings import warn
from av.audio.format cimport get_audio_format
from av.descriptor cimport wrap_avclass
from av.utils cimport media_type_to_string
from av.video.format cimport get_video_format

cdef object _cinit_sentinel = object()

cdef Codec wrap_codec(lib.AVCodec *ptr):
    cdef Codec codec = Codec(_cinit_sentinel)
    codec.ptr = ptr
    codec.is_encoder = lib.av_codec_is_encoder(ptr)
    codec._init()
    return codec

cdef flag_in_bitfield(uint64_t bitfield, uint64_t flag):
    # Not every flag exists in every version of FFMpeg and LibAV, so we
    # define them to 0.
    if not flag:
        return None
    return bool(bitfield & flag)


class UnknownCodecError(ValueError):
    pass


cdef class Codec(object):
    """A single encoding or decoding codec.

    This object exposes information about an availible codec, and an avenue to
    create a :class:`.CodecContext` to encode/decode directly.

    ::

        >>> codec = Codec('mpeg4', 'r')
        >>> codec.name
        'mpeg4'
        >>> codec.type
        'video'
        >>> codec.is_encoder
        False

    """

    def __cinit__(self, name, mode='r'):

        if name is _cinit_sentinel:
            return

        if mode in ('w','wb'):
            self.ptr = lib.avcodec_find_encoder_by_name(name)
        elif mode in ('r','rb'):
            self.ptr = lib.avcodec_find_decoder_by_name(name)
        else:
            raise ValueError('Invalid mode; must be "r" or "w".', mode)

        self._init(name)

    cdef _init(self, name=None):

        if not self.ptr:
            raise UnknownCodecError(name)

        self.desc = lib.avcodec_descriptor_get(self.ptr.id)
        if not self.desc:
            raise RuntimeError('No codec descriptor for %r.' % name)

        self.is_encoder = lib.av_codec_is_encoder(self.ptr)

        # Sanity check.
        if self.is_encoder and lib.av_codec_is_decoder(self.ptr):
            warn('%s is both encoder and decoder. Please notify PyAV developers.')

    def create(self):
        from .context import CodecContext
        return CodecContext.create(self)
    @property
    def is_decoder(self):
        return not self.is_encoder

    @property
    def descriptor(self):
        return wrap_avclass(self.ptr.priv_class)

    @property
    def name(self):
        return self.ptr.name or ''
    @property
    def long_name(self):
        return self.ptr.long_name or ''
    @property
    def type(self):
        return media_type_to_string(self.ptr.type)
    @property
    def id(self):
        return self.ptr.id

    @property
    def frame_rates(self):
        return <int>self.ptr.supported_framerates
    @property
    def audio_rates(self):
        return <int>self.ptr.supported_samplerates

    @property
    def video_formats(self):
        if not self.ptr.pix_fmts:
            return
        ret = []
        cdef lib.AVPixelFormat *ptr = self.ptr.pix_fmts
        while ptr[0] != -1:
            ret.append(get_video_format(ptr[0], 0, 0))
            ptr += 1
        return ret
    @property
    def audio_formats(self):
        if not self.ptr.sample_fmts:
            return
        ret = []
        cdef lib.AVSampleFormat *ptr = self.ptr.sample_fmts
        while ptr[0] != -1:
            ret.append(get_audio_format(ptr[0]))
            ptr += 1
        return ret


    # Capabilities.
    @property
    def draw_horiz_band(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_DRAW_HORIZ_BAND)
    @property
    def dr1(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_DR1)
    @property
    def truncated(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_TRUNCATED)
    @property
    def hwaccel(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_HWACCEL)
    @property
    def delay(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_DELAY)
    @property
    def small_last_frame(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_SMALL_LAST_FRAME)
    @property
    def hwaccel_vdpau(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_HWACCEL_VDPAU)
    @property
    def subframes(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_SUBFRAMES)
    @property
    def experimental(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_EXPERIMENTAL)
    @property
    def channel_conf(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_CHANNEL_CONF)
    @property
    def neg_linesizes(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_NEG_LINESIZES)
    @property
    def frame_threads(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_FRAME_THREADS)
    @property
    def slice_threads(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_SLICE_THREADS)
    @property
    def param_change(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_PARAM_CHANGE)
    @property
    def auto_threads(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_AUTO_THREADS)
    @property
    def variable_frame_size(self):
        return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_VARIABLE_FRAME_SIZE)

    # Capabilities and properties overlap.
    # TODO: Is this really the right way to combine these things?
    @property
    def intra_only(self):
        return (
            flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_INTRA_ONLY) or
            flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_INTRA_ONLY)
        )
    @property
    def lossless(self):
        return (
            flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_LOSSLESS) or
            flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_LOSSLESS)
        )
    @property
    def lossy(self):
        return (
            flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_LOSSY) or
            not self.lossless
        )

    # Properties.
    @property
    def reorder(self):
        return flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_REORDER)
    @property
    def bitmap_sub(self):
        return flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_BITMAP_SUB)
    @property
    def text_sub(self):
        return flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_TEXT_SUB)



codecs_availible = set()
cdef lib.AVCodec *ptr = lib.av_codec_next(NULL)
while ptr:
    codecs_availible.add(ptr.name)
    ptr = lib.av_codec_next(ptr)


def dump_codecs():
    """Print information about availible codecs."""

    print '''Codecs:
 D..... = Decoding supported
 .E.... = Encoding supported
 ..V... = Video codec
 ..A... = Audio codec
 ..S... = Subtitle codec
 ...I.. = Intra frame-only codec
 ....L. = Lossy compression
 .....S = Lossless compression
 ------'''

    for name in sorted(codecs_availible):

        try:
            e_codec = Codec(name, 'w')
        except ValueError:
            e_codec = None

        try:
            d_codec = Codec(name, 'r')
        except ValueError:
            d_codec = None

        # TODO: Assert these always have the same properties.
        codec = e_codec or d_codec

        print ' %s%s%s%s%s%s %-18s %s' % (
            '.D'[bool(d_codec)],
            '.E'[bool(e_codec)],
            codec.type[0].upper(),
            '.I'[codec.intra_only],
            'L.'[codec.lossless],
            '.S'[codec.lossless],
            codec.name,
            codec.long_name
        )

