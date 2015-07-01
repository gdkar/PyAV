from __future__ import print_function, division, absolute_import
import argparse, ctypes, os, sys, pprint, time, av, posix, posixpath, posixfile, posix_timers
class ModuleProxy(object):
    def __init__(self,name,prefix=None):
        self.name = name.split('.')[-1].lower() if '.' in name else name.lower()
        self.prefix = prefix or self.name
        self.module = __import__(name)
        if '.' in name:
            for seg in name.split('.')[1:]:
                self.module = getattr(self.module,seg)
    def __getattr__(self,name):
        if name.isupper():
            attr = getattr(self.module,self.prefix.upper() + '_' + name)
        else:
            attr = getattr(self.module,self.prefix+''.join([x[0].upper()+x[1:] for x in name.split('_')]))
        setattr(self,name,attr)
        return attr
class GLProxy(ModuleProxy):
    from contextlib import contextmanager
    @contextmanager
    def matrix(self):
        self.pushMatrix()
        try:
            yield
        finally:
            self.module.popMatrix()
    @contextmanager
    def attrib(self, *args):
        mask = 0
        for arg in args:
            if isinstance(arg,basestring):
                arg = getattr(selfmodule,'GL_{}_BIT'.format(arg.upper()))
            mask |= arg
        self.pushAttrib(mask)
        try:yield
        finally: self.popAttrib()
    def enable(self, *args, **kwargs):
        self._enable(True,*args,**kwargs)
        return self._apply_on_exit(self._enable,False,*args,**kwargs)
    def disable(self,*args,**kwaargs):
        self._enable(False,*args,**kwargs)
        return self._apply_on_exit(self._enable,True,*args,**kwargs)
    def _enable(self,enable,*args,**kwargs):
        todo = list()
        for arg in args:
            if isinstance(arg,basestring):
                arg = getattr(self.module,'GL_{}'.format(arg.upper()))
            if arg: todo.append((arg,enable))
        for key,value in kwargs.iteritems():
            flag = getattr(self.module,'GL_{}'.format(key.upper()))
            value= value if enable else not value
            todo.append((flag,value))
        for flag,value in todo:
            if value:
                self.module.nable(flag)
            else:
                self.module.glDisable(flag)
    def begin(self,arg):
        if isinstance(arg,basestring):
            arg = getattr(self.module,'GL_{}'.format(arg.upper()))
        if arg: 
            self.module.glBegin(arg)
            return self._apply_on_exit(self.module.glEnd)
    @contextmanager
    def _apply_on_exit(self,func,*args,**kwargs):
        try: yield
        finally: func(*args,**kwargs)


gl   = GLProxy('OpenGL.GL')
glx  = ModuleProxy('OpenGL.GLX','glX')
#glu  = ModuleProxy('OpenGL.GLU')
#glx  = ModuleProxy('OpenGL.GLX')
#glut = ModuleProxy('OpenGL.GLUT')
                
from PyQt5 import Qt as q, QtWidgets as qw, QtGui as qg, QtMultimedia as qm
from PyQt5.Qt import Qt as qconst

class VideoOpenGLWidget(q.QOpenGLWidget):
    def __init__(self,parent=None,*args,**kwargs):
        super(self.__class__,self).__init__(*args,parent=parent,**kwargs)
        self.fmt = q.QSurfaceFormat.defaultFormat()
        self.fmt.setSamples(8)
        self.setFormat(self.fmt)

        self.wwidth      = None
        self.wheight     = None
        self.layout      = q.QHBoxLayout()
        self.setLayout(self.layout)
    def sizeHint(self):
        if not self.wwidth: return q.QWidget.sizeHint(self)
        return q.QSize(self.wwidth,self.wheight)
    def initializeGL(self):
        self.context = q.QOpenGLContext.currentContext()
        gl.clearColor(0,0,0,0)
        gl.enable(gl.TEXTURE_2D)
        self.tex_id = gl.genTextures(1)
        gl.bindTexture(gl.TEXTURE_2D,self.tex_id)
        gl.texParameter(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR)
        gl.texParameter(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR)
        print("Generated Texture ID {}".format(self.tex_id))
#class PlayListItem(Q.QListWidgetItem):
#    def __init__(self,path,*args,**kwargs):
#        super(self.__class__,self).__init__(*args,**kwargs)
#        self.path = path
#        self.setText(posixpath.basename(self.path))
#class PlayList(Q.QListWidget):
#    def __init__(self,player,*args,**kwargs):
#        super(self.__class__,self).__init__(*args,**kwargs)
#        self.player = player
#        self.player.playlistchanged.connect(self.onplaylistchanged)
#        self.itemDoubleClicked.connect(self.clicked)
#    def onplaylistchanged(self):
#        for i, item in enumerate(self.player.playlist):
#            existingitem = self.item(i)
#            if not existingitem or existingitem.path != item['filename']:
#                self.insertItem(i,PlayListItem(item['filename']))
#            if i == self.player.playlist_pos:
#                self.setCurrentRow()
#    def clicked(self,item):
#        self.player.set_property('playlist-pos',self.row(item))
class BeatOff(q.QMainWindow):
    def reconfig(self,width,height):
        pass
    def __init__(self,player,*args,**kwargs):
        super(self.__class__,self).__init__()
        pass

if __name__ == '__main__':
    app = q.QApplication(sys.argv)
    win = BeatOff(*sys.argv[1:])
    win.show()
    app.exec_()
