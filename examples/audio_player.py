import array
import argparse
import sys
import pprint
import subprocess
import time
from qtproxy import Q
import av
app = Q.Application([])
parser = argparse.ArgumentParser()
parser.add_argument('path')
args = parser.parse_args()
container = av.open(args.path)
stream = next(s for s in container.streams if s.type == 'audio')
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
bps = 4
output = Q.AudioOutput(qformat)
output.setBufferSize(2 * 2 * 48000*250e-3)
def decode_iter():
    try:
        for pi, packet in enumerate(container.demux(stream)):
            for fi, frame in enumerate(packet.decode()):
                yield  frame
    except:
        return
global device
class decode_source(Q.IODevice):
    def __init__(self, c, dev,out,*args, **kwargs):
        super(self.__class__,self).__init__(*args,**kwargs)
        self.device = dev
        self.output = out
        self.s = c.streams[0]
        self.d = c.demux(self.s)
        self.f = av.AudioFifo()
        self.r = av.AudioResampler(format = av.AudioFormat('s16').packed,layout='stereo',rate=48000)
        self.data = ""
        for frame in self.s.decode(next(self.d)):
            self.f.write(self.r.resample(frame))
        while self.f.samples * 4 < self.output.bufferSize():
            for frame in self.s.decode(next(self.d)):
                self.f.write(self.r.resample(frame))
        frame = self.f.read()
        if frame and frame.planes:
            self.data += frame.planes[0].to_bytes()
            written = self.device.write(self.data);
            if written:
                self.data=self.data[written:]
    def readData(self, data, maxSize):
        _data =  self.f.read(maxSize/4).panes[0].to_bytes()
        ret = len(_data)
        data = _data
        print(data)
        return ret
    def bytesAvailable(self):
        return  self.f.samples * 4
    def on_decode(self,*args):
        while self.f.samples < 48000/4:
            self.f.write(self.r.resample(self.s.decode(next(self.d))[0]))
    def on_timeout(self,*args):
        self.f.write(self.r.resample(self.s.decode(next(self.d))[0]))
        self.data += self.f.read().planes[0].to_bytes()
        if  (self.output.bufferSize()/2 < self.output.bytesFree()):
            written = self.device.write(self.data[:self.output.periodSize()*8 - (self.output.bufferSize()-self.output.bytesFree() )])
            if(written):
                self.data=self.data[written:]
device = output.start()
src = decode_source(container,device,output)
src.open(Q.QIODevice.ReadOnly)
timer = Q.QTimer()
timer.setInterval(24.)
timer.timeout.connect(src.on_timeout)
timer.start()

print("device open mode is ",device.openMode())
print("device is open? ",device.isOpen())
print qformat, output, device
    #for pi, fi, frame in decode_iter():
#    frame = resampler.resample(frame)
#    if(not frame or not frame.planes): continue
#    print pi, fi, frame, output.state()
#    bytes_buffered = output.bufferSize() - output.bytesFree()
#    us_processed = output.processedUSecs()
#    us_buffered = 1000000 * bytes_buffered / (2 * 16 / 8) / 48000
#    print 'pts: %.3f, played: %.3f, buffered: %.3f' % (frame.time or 0, us_processed / 1000000.0, us_buffered / 1000000.0)
#    data = frame.planes[0].to_bytes()
#    while data:
#        written = device.write(data)
#        if written:
#            # print 'wrote', written
#            data = data[written:]
#        else:
#            # print 'did not accept data; sleeping'
#            time.sleep(0.033)
#    if False and pi % 100 == 0:
#        output.reset()
#        print output.state(), output.error()
#        device = output.start()
#
#    # time.sleep(0.05)
timer.start()
print("period size is",  output.periodSize())
app.exec_()
while output.state() == Q.Audio.ActiveState:
    time.sleep(0.1)
