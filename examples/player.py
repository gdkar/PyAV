from __future__ import division, print_function
import argparse
import ctypes
import posix, posixpath 
import sys
import pprint
import time

from qtproxy import Q

import av
fifo = av.AudioFifo()
resampler = av.AudioResampler(
    format=av.AudioFormat('s16').packed,
    layout='stereo',
    rate=48000,
)
qformat = Q.AudioFormat()
qformat.setByteOrder(Q.AudioFormat.LittleEndian)
qformat.setChannelCount(2)
qformat.setCodec('audio/pcm')
qformat.setSampleRate(48000)
qformat.setSampleSize(16)
qformat.setSampleType(Q.AudioFormat.SignedInt)

output = Q.AudioOutput(qformat)
output.setBufferSize(2 * 2 * 48000*24e-3)

device = output.start()

#WIDTH = 960
#HEIGHT = 540


class PlayerGLWidget(Q.OpenGLWidget):
    def __init__(self):
        super(self.__class__,self).__init__()
        fmt = Q.SurfaceFormat.defaultFormat()
        fmt.setSamples(8)
        self.setFormat(fmt)
        self.width  = 0;
        self.height = 0;
        self.w=0;
        self.h=0;
        self.xratio  = 0;
        self.yratio  = 0;
    def initializeGL(self):
        self.context = Q.QOpenGLContext.currentContext()

        print('initialize GL')
        gl.clearColor(0, 0, 0, 0)
        gl.enable(gl.TEXTURE_2D)

        # gl.texEnv(gl.TEXTURE_ENV, gl.TEXTURE_ENV_MODE, gl.DECAL)
        self.tex_id = gl.genTextures(1)
        gl.bindTexture(gl.TEXTURE_2D, self.tex_id)
        gl.texParameter(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameter(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

        print('texture id', self.tex_id)

    def setImage(self, w, h, img):
        gl.bindTexture(gl.TEXTURE_2D,self.tex_id)
        gl.texImage2D(gl.TEXTURE_2D, 0, 3, w, h, 0, gl.RGB, gl.UNSIGNED_BYTE, img)
        self.w=w
        self.h=h
        self.xratio = self.w/self.width
        self.yratio = self.h/self.height
        if self.xratio > self.yratio:
            self.yratio /= self.xratio
            self.xratio  = 1
        else:
            self.xratio = self.xratio/self.yratio
            self.yratio = 1
    def resizeGL(self, w, h):
        print('resize to', w, h)
        gl.viewport(0,0,w,h)
        self.width = w
        self.height= h
        self.xratio = self.w/self.width
        self.yratio = self.h/self.height
        if self.xratio > self.yratio:
            self.yratio /= self.xratio
            self.xratio  = 1
        else:
            self.xratio = self.xratio/self.yratio
            self.yratio = 1
        # gl.matrixMode(gl.PROJECTION)
        # gl.loadIdentity()
        # gl.ortho(0, w, 0, h, -10, 10)
        # gl.matrixMode(gl.MODELVIEW)

    def paintGL(self):
        # print 'paint!'
        gl.clear(gl.COLOR_BUFFER_BIT)
        gl.bindTexture(gl.TEXTURE_2D,self.tex_id)
        with gl.begin('polygon'):
            gl.texCoord(0, 0); gl.vertex(-self.xratio,  self.yratio)
            gl.texCoord(1, 0); gl.vertex( self.xratio,  self.yratio)
            gl.texCoord(1, 1); gl.vertex( self.xratio, -self.yratio)
            gl.texCoord(0, 1); gl.vertex(-self.xratio, -self.yratio)



parser = argparse.ArgumentParser()
parser.add_argument('-f', '--format')
parser.add_argument('path')
args = parser.parse_args()
import Queue
vid = av.open(args.path, format=args.format)
aud = av.open(args.path, format=args.format)
class splitter(object):
    def __init__(self, c):
        self.c = c
        self.q = []
        for s in c.streams:self.q.append(Queue.Queue())
        self.d = self.c.demux()
    def get(self,index):
        while 1:
            if not self.q[index].empty(): 
                p = self.q[index].get()
                if p:return p
            p = self.d.next()
            self.q[p.stream.index].put(p)
med = splitter(vid)

def _iter_audio(med):
    try:
        while True:
            yield med.get(0).decode()[0]
    except:
        return

class  _iter_images():
    def __init__(self,med):
        self.med  =med 
        self.frames=[]
        while not len(self.frames):
            self.frames = self.med.get(1).decode() 
    def next(self):
        while not self.frames:
            self.frames = self.med.get(1).decode()
        frame = self.frames.pop(0)
        return frame.reformat(frame.width,frame.height,'rgb24')

image_iter = _iter_images(med)
audio_iter = _iter_audio (med)
app = Q.Application([])

glwidget = PlayerGLWidget()
#glwidget.setFixedWidth(image_iter.frames[0].width)
#glwidget.setFixedHeight(image_iter.frames[0].height)
glwidget.show()
glwidget.raise_()

start_time = 0
count = 0

atimer = Q.Timer()
atimer.setInterval(24)
atimer.setTimerType(Q.PreciseTimer)
vtimer = Q.Timer()
vtimer.setInterval(1000/33)
data = b''
global audio_time 
audio_time = 0
@atimer.timeout.connect
def on_timeout(*args):
    global start_time, count,data,resampler,device,audio_time
    if not len(data):
        frame = resampler.resample(next(audio_iter))
        audio_time = frame.time
        data += frame.planes[0].to_bytes()
        data = resampler.resample(next(audio_iter)).planes[0].to_bytes()
    written = device.write(data)
    if written: 
        data = data[written:]
        if not len(data):
            frame = resampler.resample(next(audio_iter))
            audio_time = frame.time
            data += frame.planes[0].to_bytes()
            written = device.write(data)
            if written: data = data[written:]
frame = next(image_iter)
@vtimer.timeout.connect
def on_timeout(*args):
    global frame, start_time, count,data,resampler,device,audio_time
    start_time = start_time or time.time()
    elapsed = output.elapsedUSecs()*1e-6
    if frame.time <= audio_time: 
        ptr = ctypes.c_void_p(frame.planes[0].ptr)
    #glwidget.setFixedWidth(frame.width)
    #glwidget.setFixedHeight(frame.height)
        glwidget.setImage(frame.width, frame.height, ptr)
        glwidget.update()
        count += 1
        frame = next(image_iter)
        elapsed = output.elapsedUSecs()*1e-6
        print(frame.pts, frame.dts, '{:.2f}fps'.format( (count / elapsed)))

vtimer.start()
atimer.start()

app.exec_()
