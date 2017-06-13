cimport libav as lib
from libc.stdint cimport intptr_t, int64_t, uint64_t, int32_t, uint32_t, int16_t, uint16_t, int8_t, uint8_t
from av.descriptor cimport wrap_avclass
import weakref

cdef object _cinit_bypass_sentinel = object()
cdef object _format_cache = weakref.WeakValueDictionary()
cdef set _input_names = set()
cdef set _output_names = set()
cdef set _names        = set()
input_names = _input_names
output_names = _output_names
names        = _names

cdef ContainerFormat build_container_format(const lib.AVInputFormat* iptr, const lib.AVOutputFormat* optr):
    if not iptr and not optr:
        raise ValueError('needs input format or output format')
    cdef intptr_t _iptr = <intptr_t>iptr
    cdef intptr_t _optr = <intptr_t>optr
    cdef ContainerFormat cached = _format_cache.get((_iptr,_optr),None)
    cdef tuple key
    cdef str mode = None
    cdef str name = None
    if cached is None:
        cached = ContainerFormat.__new__(ContainerFormat, _cinit_bypass_sentinel)
        cached.iptr = iptr
        cached.optr = optr
        cached.name = optr.name if optr else iptr.name
        _format_cache[(_iptr,_optr)] = cached
        name = cached.name
        if iptr == NULL:    mode = 'w'
        elif optr == NULL:  mode = 'r'
        key = (name,mode)
        _format_cache[key] = cached
        for sub in name.split(','):
            key = (sub,mode)
            _format_cache[key] = cached
    return cached

cdef class ContainerFormat:

    """Descriptor of a container format.

    :param str name: The name of the format.
    :param str mode: ``'r'`` or ``'w'`` for input and output formats; defaults
        to None which will grab either.

    """
    @staticmethod
    cdef ContainerFormat _create(str name, str mode = None):
        cdef tuple key
        if mode in ('r','rb',b'r',b'rb'):
            key = (name, 'r')
        elif mode in ('w','wb',b'w',b'wb'):
            key = (name, 'w')
        else:
            key = (name, None)
        cdef ContainerFormat cached = _format_cache.get(key,None)
        cdef intptr_t _iptr = 0
        cdef intptr_t _optr = 0
        if cached is None:
            cached = ContainerFormat.__new__(ContainerFormat,key[0],mode=key[1])
            _format_cache[key] = cached
            _iptr = <intptr_t>cached.iptr
            _optr = <intptr_t>cached.optr
            _format_cache[(_iptr,_optr)] = cached
        return cached

    @staticmethod
    def create(name, mode = None):
        return ContainerFormat._create(name,mode)

    def __cinit__(self, name, mode=None):
        if name is _cinit_bypass_sentinel:
            return
        # We need to hold onto the original name because AVInputFormat.name
        # is actually comma-seperated, and so we need to remember which one
        # this was.
        self.name = name
        # Searches comma-seperated names.
        cdef tuple key = None
        if mode in ('r','rb',b'r',b'rb'):
            mode = 'r'
        elif mode in ('w','wb',b'w',b'wb'):
            mode = 'w'
        if mode is None or mode is 'r':
            self.iptr = lib.av_find_input_format(name)
        if mode is None or mode is 'w':
            self.optr = lib.av_guess_format(name, NULL, NULL )
            if self.optr is NULL:
                while True:
                    self.optr = lib.av_oformat_next(self.optr)
                    if not self.optr or self.optr.name == name:
                        break

        if not self.iptr and not self.optr:
            raise ValueError('no container format {}'.format( name))

        self.name = self.optr.name if self.optr else self.iptr.name

        cdef intptr_t _iptr = <intptr_t>self.iptr
        cdef intptr_t _optr = <intptr_t>self.optr

        cdef ContainerFormat cached = _format_cache.get((_iptr,_optr),None)
        if cached is not None:
            raise ValueError("attempting to create new copy of cached descriptor for {}, mode {}".format(name,mode))

        _format_cache[(_iptr,_optr)] = self
        cdef str sub
        for sub in self.name.split(','):
            key = ( sub, mode)
            _format_cache[key] = self

    def __repr__(self):
        return '<av.{} {}>'.format(self.__class__.__name__, self.name)

    @property
    def descriptor(self):
        if self.iptr:
            return wrap_avclass(self.iptr.priv_class)
        else:
            return wrap_avclass(self.optr.priv_class)

    @property
    def options(self):
        return self.descriptor.options

    @property
    def input(self):
        """An input-only view of this format."""
        if self.iptr == NULL:
            return None
        elif self.optr == NULL:
            return self
        else:
            return build_container_format(self.iptr, NULL)

    @property
    def output(self):
        """An output-only view of this format."""
        if self.optr == NULL:
            return None
        elif self.iptr == NULL:
            return self
        else:
            return build_container_format(NULL, self.optr)

    @property
    def is_input(self):
        return self.iptr != NULL

    @property
    def is_output(self):
        return self.optr != NULL

    @property
    def long_name(self):
        # We prefer the output names since the inputs may represent
        # multiple formats.
        return self.optr.long_name if self.optr else self.iptr.long_name

    @property
    def extensions(self):
        cdef set exts = set()
        if self.iptr and self.iptr.extensions:
            exts.update(self.iptr.extensions.split(','))
        if self.optr and self.optr.extensions:
            exts.update(self.optr.extensions.split(','))
        return exts


cdef const lib.AVInputFormat *iptr = NULL
cdef str _name, sub
while True:
    iptr = lib.av_iformat_next(iptr)
    if not iptr:
        break
    _name = iptr.name
    for sub in _name.split(','):
        input_names.add(sub)
    input_names.add(_name)

cdef const lib.AVOutputFormat *optr = NULL

while True:
    optr = lib.av_oformat_next(optr)
    if not optr:
        break
    _name = optr.name
    for sub in _name.split(','):
        output_names.add(sub)
    output_names.add(_name)
_name = None
sub = None
names.update(input_names)
names.update(output_names)
