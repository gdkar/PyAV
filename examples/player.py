
try:
    str
except NameError:
    str = str

import argparse
import ctypes
import struct, array
import os
import sys
import pprint
import time

from PyQt5.QtCore import QCoreApplication, Qt

from PyQt5 import Qt as Q
fmt = Q.QSurfaceFormat.defaultFormat()
fmt.setVersion(4,5)
fmt.setProfile(Q.QSurfaceFormat.CoreProfile)
fmt.setProfile(Q.QSurfaceFormat.CoreProfile)
#fmt.setSamples(0)
Q.QSurfaceFormat.setDefaultFormat(fmt)
#Q.QCoreApplication.setAttribute(Q.Qt.AA_ShareOpenGLContexts)

from PyQt5 import Qt as Q, QtCore as QC, QtWidgets as QW, QtGui as QG, QtOpenGL as QOGL
#from qtproxy import Q
#import ModernGL as GL
#from glproxy import gl

import av

#WIDTH = 960
#HEIGHT = 540


class PlayerGLWidget(Q.QOpenGLWidget):

    def __init__(self, container, *args, **kwargs):
        super().__init__(*args,**kwargs)

        self.container  = container
        self.stream     = next(s for s in self.container.streams if s.type=='video')
        self.demuxed    = self.container.demux(self.stream)
        self.frameCache = []
        self.frameGen   = None
#        self.setSizePolicy(Q.SizePolicy.Expanding,Q.SizePolicy.Expanding)
        self.img_width      = self.stream.width
        self.img_height     = self.stream.height
        self.img_update     = None
        self.setFixedSize(self.img_width,self.img_height)
        self.width = self.img_width
        self.tex_id = 0
        self.height = self.img_height

        self.frameTimer = Q.QTimer()
        self.frameTimer.setTimerType(Q.Qt.PreciseTimer)
        self.frameTimer.setInterval(1000.0 * self.stream.rate)
        self.frameTimer.timeout.connect(self.onTimeout)
        self.frameTimer.start()

    def nextFrame(self):
        while not self.frameCache:
            self.frameCache = next(self.demuxed).decode()
        return self.frameCache.pop(0)

    @Q.pyqtSlot()
    def onTimeout(self):
        img = self.nextFrame()
        w = img.width
        h = img.height
        self.img_update = img.reformat(w,h,'rgba')
        self.update()

    def initializeGL(self):
        print('initialize GL')
        try:
            self.ctx = self.context()
            prog = Q.QOpenGLShaderProgram()
            prog.addShaderFromSourceCode(
            Q.QOpenGLShader.Vertex ,"""
#version 330 core
out vec2 v_texcoord;
void main(void) {
    vec2 vertex;
    switch(gl_VertexID) {
        case 0: vertex = vec2(1.,1.);break;
        case 1: vertex = vec2(1.,-1.);break;
        case 2: vertex = vec2(-1.,1.);break;
        case 3: vertex = vec2(-1.,-1.);break;
        default:vertex = vec2(0.,0.);break;
    }
    gl_Position = vec4(vertex.x,-vertex.y, 0., 1.);
    v_texcoord  = (vertex + vec2(1.,1.)) * .5;
}""")
            print(prog.log())
            prog.addShaderFromSourceCode(
            Q.QOpenGLShader.Fragment ,"""
#version 330 core
in vec2  v_texcoord;
layout(location=0) out vec4 f_fragcolor;
uniform sampler2D u_sampler;
void main(void) {
//    f_fragcolor = vec4(v_texcoord,0,1.);
    f_fragcolor = texture(u_sampler, v_texcoord);
    f_fragcolor.a = 1.;
}""")
            print(prog.log())
            self.prog = prog
            self.prog.link()
            self.prog.bind()
            print(prog.log())
            pfl = Q.QOpenGLVersionProfile()
            pfl.setVersion(4,1)
            pfl.setProfile(Q.QSurfaceFormat.CoreProfile)
            vgl = self.context().versionFunctions(pfl)
            print(vgl.glGetError())
            prog.setUniformValue('u_sampler',0)
            print(self.prog.log())
            print(self.prog,self)
            for s in self.prog.shaders():
                print(s.log())
#            self.fbo = Q.QOpenGLFramebufferObject(Q.QSize(self.img_width,self.img_height),Q.QOpenGLTexture.Target2D)
            self.tex = Q.QOpenGLTexture(Q.QOpenGLTexture.Target2D)
            self.tex.setSize(self.img_width,self.img_height)
            self.tex.setFormat(self.tex.RGBA32F)
#            self.tex.allocateStorage(self.tex.RGBA, self.tex.UInt8)
#            self.tex.setMinMagFilters(self.tex.Linear,self.tex.Linear)
#            self.tex.setWrapMode(self.tex.ClampToEdge)

#            self.tex = .Texture((self.img_width,self.img_height),4,bytes(self.img_width*self.img_height*4))
#            print(self.fbo)
#            print(self.fbo.handle())
#            print(self.fbo.texture())
            print(self.tex)
            print(self.tex.textureId())
#            self.tex.use()
        except Exception as error:
            print("Error: ",error)
            raise
#        print(('texture id', self.tex))
    def setImage(self,img):
        if not img:return
        w = img.width
        h = img.height
        if (w,h) != (self.img_width,self.img_height):
            self.setMinimumWidth(w)
            self.setMinimumHeight(h)
            self.parent().update()
        if not self.tex or self.tex.width() != w or self.tex.height() != h:
            self.tex = Q.QOpenGLTexture(Q.QOpenGLTexture.Target2D)
            self.tex.setFormat(self.tex.RGBA8)
#            self.tex.destroy()
            self.tex.setSize(w,h)
            self.tex.allocateStorage(self.tex.RGBA, self.tex.UInt8)
        print(img)
        print(img.planes)
        self.tex.setData(self.tex.RGBA, self.tex.UInt8,img.planes[0].to_bytes())
#            else:
#                self.tex.update(data=img.planes[0].to_bytes())
        self.img_width  = w
        self.img_height = h
    def resizeGL(self, w, h):
        print(('resize to', w, h))
        self.width  = w
        self.height = h

    def paintGL(self):
        img_update, self.img_update = self.img_update, None
        self.setImage(img_update)
        hratio = self.img_width*1.0/self.width
        vratio = self.img_height*1.0/self.height
        dratio = max(hratio,vratio)
        hratio /= dratio
        vratio /= dratio

#        vgl = self.vgl
#        vgl.glViewport(0,0,self.width*hratio,self.height*vratio)
#        vgl.glClearColor(0,0,0,0)
#        vgl.glClear(vgl.GL_COLOR_BUFFER_BIT)

#        self..clear(0,0,0,0)
#        if self.tex:
#        vgl.glActiveTexture(vgl.GL_TEXTURE0)
#        vgl.glBindTexture(vgl.GL_TEXTURE_2D, self.tex.textureId())
#        self.tex.bind()
#        vgl.glUseProgram(self.prog.programId())
        pfl = Q.QOpenGLVersionProfile()
        pfl.setVersion(4,1)
        pfl.setProfile(Q.QSurfaceFormat.CoreProfile)
        vgl = Q.QOpenGLContext.currentContext().versionFunctions(pfl)
        vgl.glViewport(0, 0, self.width * hratio, -self.height * vratio)
        vgl.glClearColor(0,0,0,0)
        vgl.glClear(vgl.GL_COLOR_BUFFER_BIT|vgl.GL_DEPTH_BUFFER_BIT)
        vgl.glDisable(vgl.GL_BLEND)
        vgl.glDisable(vgl.GL_DEPTH_TEST)
        self.tex.bind(0)
        self.prog.bind()

        vgl.glDrawArrays(vgl.GL_TRIANGLE_STRIP, 0,4)
        self.tex.release(0)
        self.prog.release()

#        self.prog.release()
#        self.tex.release()
#        if self.tex:
#            self.ctx.viewport = (0, 0, self.width * hratio, self.height* vratio)
#            self.tex.use()
#            self.vao.render(GL.TRIANGLE_STRIP)

class Canvas(Q.QMainWindow):
    def __init__(self,filename,format=None,parent=None):
        super(self.__class__,self).__init__(parent)
        self.widget = PlayerGLWidget(container=av.open(filename))
        self.setCentralWidget(self.widget)


parser = argparse.ArgumentParser()
parser.add_argument('-f', '--format')
parser.add_argument('path')
args = parser.parse_args()

app = Q.QApplication ([])

glcanvas = Canvas(args.path,format=args.format)
glcanvas.show()
glcanvas.raise_()
#glwidget = PlayerGLWidget(container=av.open(args.path,format=args.format))
#glwidget.setFixedWidth(WIDTH)
#glwidget.setFixedHeight(HEIGHT)
#glwidget.setSizePolicy(Q.SizePolicy.Expanding,Q.SizePolicy.Expanding)
#glwidget.show()
#glwidget.raise_()

#@timer.timeout.connect
#def on_timeout(*args):

#    global start_time, count
#    start_time = start_time or time.time()

#    frame = next(image_iter)
#    ptr = ctypes.c_void_p(frame.planes[0].ptr)
#    glwidget.setImage(frame.width, frame.height, ptr)
#    glwidget.updateGL()

#    count += 1
#    elapsed = time.time() - start_time
#    print(frame.pts, frame.dts, '%.2ffps' % (count / elapsed))

#timer.start()

app.exec_()
