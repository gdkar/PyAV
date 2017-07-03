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
        self._width = self.img_width
        self.tex_id = 0
        self._height = self.img_height
#        self.decodeThread = Q.Thread()
        self.frameTimer = Q.QTimer()
        self.frameTimer.setTimerType(Q.PreciseTimer)
        self.frameTimer.setInterval(int(1000*self.stream.rate))
        self.frameTimer.timeout.connect(self.onTimeout)
        self.frameTimer.start()
#        self.decodeThread.start()
    def nextFrame(self):
        while not self.frameCache:
            self.frameCache.extend(next(self.demuxed).decode())
        return self.frameCache.pop(0)

    @Q.pyqtSlot()
    def onTimeout(self):
        img = self.nextFrame()
        w = img.width
        h = img.height
        self.setImage(w,h,img.reformat(w,h,"rgba"))

    def initializeGL(self):
        print('initialize GL')
        try:
            self.ctx = GL.create_context()
#            GL.Viewport(0, 0, self.width,self.height)
            vert = self.ctx.vertex_shader("""
#version 430
in  vec2 a_position;
out vec2 v_texcoord;
void main(void) {
    gl_Position = vec4(a_position.x,-a_position.y, 0., 1.);
    v_texcoord  = (a_position + vec2(1.,1.)) * vec2(.5,.5);
}""")
            frag = self.ctx.fragment_shader("""
#version 430
in vec2  v_texcoord;
out vec4 f_fragcolor;
uniform sampler2D u_sampler;
void main(void) {
    f_fragcolor = texture(u_sampler, v_texcoord);
}""")
            self.prog = self.ctx.program([vert,frag])
            self.vbo = self.ctx.buffer(struct.pack('8f', -1.,-1.,-1.,1.,1.,-1.,1.,1.))
            self.vao = self.ctx.simple_vertex_array(self.prog,self.vbo,['a_position'])
            self.tex = self.ctx.texture((self.img_width,self.img_height),4,bytes(self.img_width*self.img_height*4))
            self.tex.use()
        except GL.Error as error:
            print("Error: ",error)
            exit(1)
        print(('texture id', self.tex))
    def setImage(self,w,h,img):
        try:
            self.prog
            if self.tex.width != w or self.tex.height != h:
                self.tex = self.ctx.texture((w,h),4,img.planes[0].to_bytes())
                print(("setting new image, size {}x{}, tex={}".format(w,h,repr(self.tex))))
            else:
                self.tex.write(img.planes[0].to_bytes())
            self.tex.use()
            self.img_width  = w
            self.img_height = h
            self.update()
        except:
            pass
    def resizeGL(self, w, h):
        print(('resize to', w, h))
        self._width  = w
        self._height = h
        # gl.matrixMode(gl.PROJECTION)
        # gl.loadIdentity()
        # gl.ortho(0, w, 0, h, -10, 10)
        # gl.matrixMode(gl.MODELVIEW)
    def paintGL(self):
        hratio = self.img_width*1.0/self._width
        vratio = self.img_height*1.0/self._height
        dratio = max(hratio,vratio)
        hratio /= dratio
        vratio /= dratio
        if self.tex:
            self.ctx.viewport = (0, 0, hratio*self.width(), vratio*self.height())
            self.ctx.clear(0,0,0,0)
            self.tex.use()
            self.vao.render(GL.TRIANGLE_STRIP)

class Canvas(Q.QMainWindow):
    def __init__(self,filename,format=None,parent=None):
        super(self.__class__,self).__init__(parent)
        self.widget = PlayerGLWidget(container=av.open(filename))
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
