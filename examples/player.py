
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

from qtproxy import Q
import ModernGL as GL
#from glproxy import gl

import av

WIDTH = 960
HEIGHT = 540


class PlayerGLWidget(Q.OpenGLWidget):

    def __init__(self, container, *args, **kwargs):
        super(self.__class__,self).__init__(*args,**kwargs)

        self.container  = container
        self.stream     = next(s for s in self.container.streams if s.type=='video')
        self.demuxed    = self.container.demux(self.stream)
        self.frameCache = []
        self.img_width      = self.stream.width
        self.img_height     = self.stream.height
        self.width = self.img_width
        self.tex_id = 0
        self.height = self.img_height
#        self.decodeThread = Q.Thread()
        self.frameTimer = Q.QTimer()
        self.frameTimer.setTimerType(Q.PreciseTimer)
        self.frameTimer.setInterval(1000/30)
        self.frameTimer.timeout.connect(self.onTimeout)
        self.frameTimer.start()
#        self.decodeThread.start()
    def nextFrame(self):
        while not self.frameCache:
            self.frameCache = next(self.demuxed).decode()
        return self.frameCache.pop(0)

    @Q.pyqtSlot()
    def onTimeout(self):
        print("received a timer event!")
        img = self.nextFrame()
        w = img.width
        h = img.height
        self.setImage(w,h,img.reformat(w,h,"rgb24"))

    def initializeGL(self):
        print('initialize GL')
        try:
            GL.Init()
            GL.Viewport(0, 0, self.width,self.height)
            vert = GL.NewVertexShader("""
#version 430
in  vec2 a_position;
out vec2 v_texcoord;
void main(void) {
    gl_Position = vec4(a_position, 0., 1.);
    v_texcoord  = (a_position + vec2(1.,1.)) * .5;
}""")
            frag = GL.NewFragmentShader("""
#version 430
in vec2  v_texcoord;
out vec4 f_fragcolor;
uniform sampler2D u_sampler;
void main(void) {
    f_fragcolor = texture(u_sampler, v_texcoord);
}""")
            self.prog = GL.NewProgram([vert,frag])
            self.iface = self.prog.interface
            self.vbo = GL.NewVertexBuffer(struct.pack('8f', -1.,-1.,-1.,1.,1.,-1.,1.,1.))
            self.vao = GL.NewVertexArray(self.prog,self.vbo,'2f',['a_position'])
            self.tex = GL.NewTexture(self.img_width,self.img_height,bytes(self.img_width*self.img_height*3))
            GL.UseTexture(self.tex)
        except GL.Error as error:
            print("Error: ",error)
            exit(1)
#            gl.clearColor(0, 0, 0, 0)
#            gl.enable(gl.TEXTURE_2D)
            # gl.texEnv(gl.TEXTURE_ENV, gl.TEXTURE_ENV_MODE, gl.DECAL)
#            self.tex_id = gl.genTextures(1)
            #gl.bindTexture(gl.TEXTURE_2D, self.tex_id)
            #gl.texParameter(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
#            gl.texParameter(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        print(('texture id', self.tex))
    def setImage(self,w,h,img):
        try:
            self.prog
            print(("setting new image, size {}x{}".format(w,h)))
#        ptr = ctypes.c_void_p(img.planes[0].to_bytes())
            self.tex = GL.NewTexture(w,h,img.planes[0].to_bytes())
            GL.UseTexture(self.tex)
#        gl.bindTexture(gl.TEXTURE_2D, self.tex_id)
#        gl.texImage2D(gl.TEXTURE_2D, 0, 3, w, h, 0, gl.RGB, gl.UNSIGNED_BYTE, ptr)
            self.img_width  = w
            self.img_height = h
            self.update()
#            self.update()
        except:
            pass
    def resizeGL(self, w, h):
        print(('resize to', w, h))
        self.width  = w
        self.height = h
        GL.Viewport(0, 0, w, h)
        # gl.matrixMode(gl.PROJECTION)
        # gl.loadIdentity()
        # gl.ortho(0, w, 0, h, -10, 10)
        # gl.matrixMode(gl.MODELVIEW)
    def paintGL(self):
        hratio = self.img_width*1.0/self.width
        vratio = self.img_height*1.0/self.height
        dratio = max(hratio,vratio)
        hratio /= dratio
        vratio /= dratio
        print('paint!')
#        gl.clear(gl.COLOR_BUFFER_BIT)
        GL.Clear(0,0,0,0)
        if self.tex:
            GL.UseTexture(self.tex)
            GL.RenderTriangleStrip(self.vao,4)
#            self.update()
#        with gl.begin('polygon'):
#            gl.texCoord(0, 0); gl.vertex(-hratio,  vratio)
            #gl.texCoord(1, 0); gl.vertex( hratio,  vratio)
            #gl.texCoord(1, 1); gl.vertex( hratio, -vratio)
            #gl.texCoord(0, 1); gl.vertex(-hratio, -vratio)

class Canvas(Q.QMainWindow):
    def __init__(self,filename,format=None,parent=None):
        super(self.__class__,self).__init__(parent)
        self.widget = PlayerGLWidget(container=av.open(filename))
        self.widget.setFixedWidth(WIDTH)
        self.widget.setFixedHeight(HEIGHT)
        self.widget.setSizePolicy(Q.SizePolicy.Expanding,Q.SizePolicy.Expanding)
        self.setCentralWidget(self.widget)
parser = argparse.ArgumentParser()
parser.add_argument('-f', '--format')
parser.add_argument('path')
args = parser.parse_args()
fmt = Q.SurfaceFormat.defaultFormat()
fmt.setVersion(4,5)
fmt.setProfile(Q.SurfaceFormat.CoreProfile)
fmt.setSamples(4)
Q.SurfaceFormat.setDefaultFormat(fmt)

app = Q.Application([])

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
