
try:
    str
except NameError:
    str = str

import argparse
import ctypes
import os
import sys
import pprint
import time

from qtproxy import Q
from glproxy import gl

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
        fmt = self.format()
        fmt.setSamples(4)
        fmt.setMajorVersion(3)
        fmt.setMinorVersion(3)
        fmt.setProfile(Q.SurfaceFormat.CoreProfile)
        self.setFormat(fmt)
        gl.clearColor(0, 0, 0, 0)
        gl.enable(gl.TEXTURE_2D)
        # gl.texEnv(gl.TEXTURE_ENV, gl.TEXTURE_ENV_MODE, gl.DECAL)
        self.tex_id = gl.genTextures(1)
        gl.bindTexture(gl.TEXTURE_2D, self.tex_id)
        gl.texParameter(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameter(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        print(('texture id', self.tex_id))
    def setImage(self,w,h,img):
        print(("setting new image, size {}x{}".format(w,h)))
        ptr = ctypes.c_void_p(img.planes[0].ptr)
        gl.bindTexture(gl.TEXTURE_2D, self.tex_id)
        gl.texImage2D(gl.TEXTURE_2D, 0, 3, w, h, 0, gl.RGB, gl.UNSIGNED_BYTE, ptr)
        self.img_width  = w
        self.img_height = h
        self.update()
    def resizeGL(self, w, h):
        print(('resize to', w, h))
        self.width  = w
        self.height = h
        gl.viewport(0, 0, w, h)
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
        gl.clear(gl.COLOR_BUFFER_BIT)
        with gl.begin('polygon'):
            gl.texCoord(0, 0); gl.vertex(-hratio,  vratio)
            gl.texCoord(1, 0); gl.vertex( hratio,  vratio)
            gl.texCoord(1, 1); gl.vertex( hratio, -vratio)
            gl.texCoord(0, 1); gl.vertex(-hratio, -vratio)
parser = argparse.ArgumentParser()
parser.add_argument('-f', '--format')
parser.add_argument('path')
args = parser.parse_args()
app = Q.Application([])

glwidget = PlayerGLWidget(container=av.open(args.path,format=args.format))
glwidget.setFixedWidth(WIDTH)
glwidget.setFixedHeight(HEIGHT)
glwidget.setSizePolicy(Q.SizePolicy.Expanding,Q.SizePolicy.Expanding)
glwidget.show()
glwidget.raise_()

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
