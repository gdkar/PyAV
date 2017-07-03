'''Mikes wrapper for the visualizer???'''
from contextlib import contextmanager
try:
    str
except NameError:
    str = str

from OpenGL.GLUT import *
from OpenGL.GLU import *
from OpenGL.GL import *
import OpenGL


__all__ = '''
    gl
    glu
    glx
    glut
'''.strip().split()


class ModuleProxy(object):
    __slots__= ('name',
                'prefix',
                'module',
                '__dict__',
                '__weakref__'
                )
    def __init__(self, name, module = None, prefix = None):
        self.name = name
        if not module:module = name
        if '.' in name:self.name = name.split('.')[-1].lower()
        else:self.name = name.lower()
        if isinstance(module,str):
            self.module = __import__(module)
            if '.' in module:
                for part in  module.split('.')[1:]:
                    self.module = getattr(self.module,part)
        else:self.module = module
        self.prefix = prefix or self.name
    def __getattr__(self, name):
        if name.isupper():
            attr = getattr(self.module, self.prefix.upper() + '_' + name)
        else:
            # convert to camel case
            attr =getattr(self.module, self.prefix + ''.join(
               [x[0].upper()+x[1:] for x in name.split('_')]
               ))
        setattr(self,name,attr)
        return attr
class GLProxy(ModuleProxy):
    @contextmanager
    def matrix(self):
        self.pushMatrix()
        try:yield
        finally: self.popMatrix()
    @contextmanager
    def attrib(self, *args):
        mask = 0
        for arg in args:
            if isinstance(arg, str):
                arg = getattr(self.module, 'GL_{arg.upper()}_BIT'.format(arg=arg))
            if arg:mask |= arg
        self.pushAttrib(mask)
        try:yield
        finally:self.popAttrib()
    
    def enable(self, *args, **kwargs):
        self._enable(True, args, kwargs)
        return self._apply_on_exit(self._enable, False, args, kwargs)
    
    def disable(self, *args, **kwargs):
        self._enable(False, args, kwargs)
        return self._apply_on_exit(self._enable, True, args, kwargs)
    
    def _enable(self, enable, args, kwargs):
        todo = []
        for arg in args:
            if isinstance(arg, str):
                arg = getattr(self.module, 'GL_%s' % arg.upper())
            todo.append((arg, enable))
        for key, value in list(kwargs.items()):
            flag = getattr(self.module, 'GL_%s' % key.upper())
            value = value if enable else not value
            todo.append((flag, value))
        for flag, value in todo:
            if value:
                self.module.glEnable(flag)
            else:
                self.module.glDisable(flag)
        
    def begin(self, arg):
        if isinstance(arg, str):
            arg = getattr(self.module, 'GL_%s' % arg.upper())
        self.module.glBegin(arg)
        return self._apply_on_exit(self.module.glEnd)
    
    @contextmanager
    def _apply_on_exit(self, func, *args, **kwargs):
        try:
            yield
        finally:
            func(*args, **kwargs)
        

gl = GLProxy('gl', OpenGL.GL)
#glu = ModuleProxy('glu', OpenGL.GLU)
#glut = ModuleProxy('glut', OpenGL.GLUT)
