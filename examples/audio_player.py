from __future__ import division, print_function
import array
import argparse
import sys
import pprint
import subprocess
import time

from qtproxy import Q
import av

parser = argparse.ArgumentParser()
parser.add_argument('path')
args = parser.parse_args()

container = av.open(args.path)
stream = next(s for s in container.streams if s.type == 'audio')



qformat = Q.AudioFormat()
qformat.setByteOrder(Q.AudioFormat.LittleEndian)
qformat.setChannelCount(2)
qformat.setCodec('audio/pcm')
qformat.setSampleRate(48000)
qformat.setSampleSize(32)
qformat.setSampleType(Q.AudioFormat.Float)
qApp = Q.QApplication([])
buffer_time = 0.0125

class PlayThread(Q.QThread ):
    def __init__ ( self,qformat, it, **kwargs ):
        super(self.__class__,self).__init__(**kwargs)
        self.qformat = qformat
        self.output  = Q.AudioOutput(qformat)
        self.output.setBufferSize(buffer_time * qformat.sampleRate() * qformat.sampleSize() * qformat.channelCount() // 8)
        self.device  = self.output.start()
        self.it = it
        self.fifo = av.AudioFifo()
        self.resampler = av.AudioResampler(
                format = av.AudioFormat("flt").packed,
                layout = "stereo",
                rate   = 48000 
                )
        self.frameSize = qformat.sampleSize() * qformat.channelCount()//8
        self.byteRate  = self.frameSize * qformat.sampleRate()
        self.start()
    def run ( self ):
        for pi, fi, frame in self.it:
            self.fifo.write(self.resampler.resample(frame))
            bytes_buffered = self.output.bufferSize() - self.output.bytesFree()
            s_processed = self.output.processedUSecs() * 1e-6
            s_buffered  = bytes_buffered / self.byteRate
#            print('pts: %.3f, played: %.3f, buffered: %.3f' % (frame.time or 0, s_processed , s_buffered ))
            samples_free = self.output.bytesFree() // self.frameSize
            while self.fifo.samples >= samples_free:
                if self.output.bytesFree() >= self.output.bufferSize() // 4:
                    frame = self.fifo.read(samples_free)
#                    print ( pi, fi, frame, self.output.state())
                    data = frame.planes[0].to_bytes()
                    written = self.device.write(data)
                    if written < len(data):
                        print("failed to write all data, {0} out of {1}".format(written,len(data)))
                bytes_buffered = self.output.bufferSize() - self.output.bytesFree()
                s_buffered  = bytes_buffered / self.byteRate
                self.usleep(int(s_buffered * 0.25e6))
                samples_free = self.output.bytesFree() // self.frameSize

def decode_iter():
    try:
        for pi, packet in enumerate(container.demux(stream)):
            for fi, frame in enumerate(packet.decode()):
                yield pi, fi, frame
    except: return
play_thread = PlayThread(qformat, decode_iter())
#device = output.start()

print(qformat, play_thread.output, play_thread.device)

while not play_thread.isFinished() :
    time.sleep(0.1)
