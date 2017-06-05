"""
Note this example only really works accurately on constant frame rate media. 
"""
from video_widgets import *
from PyQt5 import QtGui
from PyQt5 import QtWidgets
from PyQt5 import QtCore
from PyQt5 import Qt
from PyQt5.QtCore import Qt
from qtproxy import Q
import threading
import time
import sys
import av


AV_TIME_BASE = 1000000
def pts_to_frame(pts, time_base, frame_rate, start_time):
    return int(pts * time_base * frame_rate) - int(start_time * time_base * frame_rate)
def get_frame_rate(stream):
    if stream.average_rate.denominator and stream.average_rate.numerator:return float(stream.average_rate)
    if stream.time_base.denominator and stream.time_base.numerator:return 1.0/float(stream.time_base)
    else: raise ValueError("Unable to determine FPS")
def get_frame_count(f, stream):
    if stream.frames:     return stream.frames
    elif stream.duration: return pts_to_frame(stream.duration, float(stream.time_base), get_frame_rate(stream), 0)
    elif f.duration:      return pts_to_frame(f.duration, 1/float(AV_TIME_BASE), get_frame_rate(stream), 0)
    else:raise ValueError("Unable to determine number for frames")
if __name__ == "__main__":
    app = Q.Application(sys.argv)
    window = VideoPlayerWidget()
    test_file = sys.argv[1]
    window.set_file(test_file)
    window.show()
    ret = app.exec_()
    sys.exit(ret)

