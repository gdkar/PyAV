from __future__ import division

import argparse
import math
import sys
import wave
import math
import struct
import random

try:
    from itertools import izip, count, islice, imap, izip_longest
except ImportError:
    from itertools import count, islice, zip_longest as izip_longest
    izip = zip
    imap = map

try:
    xrange
except NameError:
    xrange = range

from PIL import Image
import numpy as np

import av
from av.audio.frame import AudioFrame
from av.audio.layout import AudioLayout
from av.audio.format import AudioFormat


def sine_wave(frequency=440.0, framerate=44100, amplitude=0.5):
    '''
    Generate a sine wave at a given frequency of infinite length.
    '''
    period = int(framerate / frequency)
    if amplitude > 1.0: amplitude = 1.0
    if amplitude < 0.0: amplitude = 0.0
    lookup_table = [float(amplitude) * math.sin(2.0*math.pi*float(frequency)*(float(i%period)/float(framerate))) for i in xrange(period)]
    return (lookup_table[i%period] for i in count(0))

def square_wave(frequency=440.0, framerate=44100, amplitude=0.5):
    for s in sine_wave(frequency, framerate, amplitude):
        if s > 0:
            yield amplitude
        elif s < 0:
            yield -amplitude
        else:
            yield 0.0

def damped_wave(frequency=440.0, framerate=44100, amplitude=0.5, length=44100):
    if amplitude > 1.0: amplitude = 1.0
    if amplitude < 0.0: amplitude = 0.0
    return (math.exp(-(float(i%length)/float(framerate))) * s for i, s in enumerate(sine_wave(frequency, framerate, amplitude)))

def white_noise(amplitude=0.5):
    '''
    Generate random samples.
    '''
    return (float(amplitude) * random.uniform(-1, 1) for i in count(0))

def compute_samples(channels, nsamples=None):
    '''
    create a generator which computes the samples.

    essentially it creates a sequence of the sum of each function in the channel
    at each sample in the file for each channel.
    '''
    return islice(izip(*(imap(sum, izip(*channel)) for channel in channels)), nsamples)


parser = argparse.ArgumentParser()
# parser.add_argument('-c', '--channels', help="Number of channels to produce", default=2, type="int")
parser.add_argument('-b', '--bits', help="Number of bits in each sample", default=16, type=int)
parser.add_argument('-r', '--rate', help="Sample rate in Hz", default=44100, type=int)
parser.add_argument('-t', '--time', help="Duration of the wave in seconds.", default=60, type=int)
parser.add_argument('-a', '--amplitude', help="Amplitude of the wave on a scale of 0.0-1.0.", default=0.5, type=float)
parser.add_argument('-f', '--frequency', help="Frequency of the wave in Hz", default=440.0, type=float)
parser.add_argument('-c', '--codec', default='aac')
parser.add_argument('output')

args = parser.parse_args()

print 'Calculating samples...'
channel = [sine_wave(args.frequency, args.rate, args.amplitude)]
channels = [channel]
sample_iter = compute_samples(channels, args.rate * args.time)
mono_iter = (s[0] for s in sample_iter)
array = np.array(list(mono_iter), dtype='int16')


output = av.open(args.output, 'w')

stream = output.add_stream(args.codec, args.rate)
stream.layout = AudioLayout('mono')
stream.format = AudioFormat('s16')

print 'Making frame...'
frame = AudioFrame.from_ndarray(array)

print 'Encoding frame...'
packet = stream.encode(frame)
while packet:
    output.mux(packet)
    packet = stream.encode()
    if packet:
        print '...another...'

print 'Done!'
output.close()













