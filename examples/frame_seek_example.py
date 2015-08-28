"""
Note this example only really works accurately on constant frame rate media. 
"""

from qtproxy import Q
import sys
import av

AV_TIME_BASE = 1000000

def pts_to_frame(pts, time_base, frame_rate, start_time):
    return int(pts * time_base * frame_rate) - int(start_time * time_base * frame_rate)

def get_frame_rate(stream):
    if stream.average_rate.denominator and stream.average_rate.numerator:
        return float(stream.average_rate)
    if stream.time_base.denominator and stream.time_base.numerator:
        return 1.0/float(stream.time_base)
    else: raise ValueError("Unable to determine FPS")
    
def get_frame_count(f, stream):
    if stream.frames:     return stream.frames
    elif stream.duration: return pts_to_frame(stream.duration, float(stream.time_base), get_frame_rate(stream), 0)
    elif f.duration:      return pts_to_frame(f.duration, 1/float(AV_TIME_BASE), get_frame_rate(stream), 0)
    else:                 raise ValueError("Unable to determine number for frames")

class FrameGrabber(Q.QObject):
    frame_ready = Q.pyqtSignal(object, object)
    update_frame_range = Q.pyqtSignal(object)
    def __init__(self, parent =None):
        super(FrameGrabber, self).__init__(parent)
        self.file = None
        self.stream = None
        self.frame = None
        self.active_frame = None
        self.start_time = 0
        self.pts_seen = False
        self.nb_frames = None
        self.frame_cache=dict()
        self.last_seen=-1
        self.last_shown=-1
        self.rate = None
        self.time_base = None
        
    def next_frame(self):
        frame_index = None
        rate = self.rate
        time_base = self.time_base
        self.pts_seen = False
        for packet in self.file.demux(self.stream):
            #print "    pkt", packet.pts, packet.dts, packet
            if packet.pts:self.pts_seen = True
            for frame in packet.decode():
                if frame_index is None:
                    if self.pts_seen:pts = frame.pts
                    else:pts = frame.dts
                    if not pts is None:frame_index = pts_to_frame(pts, time_base, rate, self.start_time)
                elif not frame_index is None:frame_index += 1
                yield frame_index, frame
    @Q.pyqtSlot(object)
    def request_frame(self, target_frame):
        frame = self.get_frame(target_frame)
        if not frame:return
        rgba = frame.reformat(frame.width, frame.height, "rgb24", 'itu709')
        #print rgba.to_image().save("test.png")
        # could use the buffer interface here instead, some versions of PyQt don't support it for some reason
        # need to track down which version they added support for it
        self.frame = bytearray(rgba.planes[0])
        bytesPerPixel  =3 
        img = Q.QImage(self.frame, rgba.width, rgba.height, rgba.width * bytesPerPixel, Q.QImage.Format_RGB888)
        
        #img = QtGui.QImage(rgba.planes[0], rgba.width, rgba.height, QtGui.QImage.Format_RGB888)

        #pixmap = QtGui.QPixmap.fromImage(img)
        self.frame_ready.emit(img, target_frame)
        
    def get_frame(self, target_frame):

        if target_frame != self.active_frame:return
        if target_frame in self.frame_cache:
            return self.frame_cache[target_frame]
        if (not self.frame_cache.keys() or target_frame>min(self.frame_cache.keys())) and target_frame < self.last_seen + 64:
            next_frame = self.next_frame()
            for i, (frame_index, frame) in enumerate(next_frame):
                self.frame_cache[frame_index]=frame
                self.last_seen = frame_index
                if frame_index >= target_frame or i >= 64:
                    next_frame.close()
                if frame_index == target_frame:
                    return frame
        print 'seeking to', target_frame
        seek_frame = target_frame
        rate = self.rate
        time_base = self.time_base
        frame = None
        reseek = 250
        original_target_frame_pts = None
        while reseek >= 0:
            # convert seek_frame to pts
            target_sec = seek_frame * 1/rate
            target_pts = int(target_sec / time_base) + self.start_time
            if original_target_frame_pts is None:original_target_frame_pts = target_pts
            self.stream.seek(int(target_pts))
            frame_index = None
            for index in self.frame_cache.keys():
                if abs(index-target_frame>256):
                    del self.frame_cache[index]
            for i, (frame_index, frame) in enumerate(self.next_frame()):
                self.frame_cache[frame_index] = frame
                self.last_seen = frame_index 
                # optimization if the time slider has changed, the requested frame no longer valid
#                if target_frame != self.active_frame:return
                print "   ", i, "at frame", frame_index, "at ts:", frame.pts,frame.dts,"target:", target_pts, 'orig', original_target_frame_pts
                if frame_index == target_frame:
                    return self.frame_cache[target_frame]
                if frame_index is None:pass
                if frame_index >= target_frame:break
            # Check if we over seeked, if we over seekd we need to seek to a earlier time
            # but still looking for the target frame
            if frame_index != target_frame:
                if frame_index is None:over_seek = '?'
                else:
                    over_seek = frame_index - target_frame
                    if frame_index > target_frame:
                        if target_frame in self.frame_cache:
                            return self.frame_cache[target_frame]
                        print over_seek, self.frame_cache
                        break

                    
                seek_frame -= 1
                reseek -= 1
                print "over seeked by %s, backtracking.. seeking: %i target: %i retry: %i" % (str(over_seek),  seek_frame, target_frame, reseek)

            else:
                break
        
        if reseek < 0:
            raise ValueError("seeking failed %i" % frame_index)
            
        # frame at this point should be the correct frame
        
        if frame:
            
            return frame
        
        else:
            raise ValueError("seeking failed %i" % target_frame)
        
    def get_frame_count(self):
        
        frame_count = None
        
        if self.stream.frames:
            frame_count = self.stream.frames
        elif self.stream.duration:
            frame_count =  pts_to_frame(self.stream.duration, float(self.stream.time_base), get_frame_rate(self.stream), 0)
        elif self.file.duration:
            frame_count = pts_to_frame(self.file.duration, 1/float(AV_TIME_BASE), get_frame_rate(self.stream), 0)
        else:
            raise ValueError("Unable to determine number for frames")
        
        seek_frame = frame_count
        
        retry = 100
        
        while retry:
            target_sec = seek_frame * 1/ self.rate
            target_pts = int(target_sec / self.time_base) + self.start_time
            
            self.stream.seek(int(target_pts))
            
            frame_index = None
            
            for frame_index, frame in self.next_frame():
                print frame_index, frame
                continue
            
            if not frame_index is None:
                break
            else:
                seek_frame -= 1 
                retry -= 1
                
        
        print "frame count seeked", frame_index, "container frame count", frame_count
        
        return frame_index or frame_count
    
    @Q.pyqtSlot(object)
    def set_file(self, path):
        self.file = av.open(path)
        self.stream = next(s for s in self.file.streams if s.type == b'video')
        self.rate = get_frame_rate(self.stream)
        self.time_base = float(self.stream.time_base)
        

        index, first_frame = next(self.next_frame())
        self.stream.seek(self.stream.start_time)

        # find the pts of the first frame
        index, first_frame = next(self.next_frame())

        if self.pts_seen:
            pts = first_frame.pts
        else:
            pts = first_frame.dts
 
        self.start_time = pts or first_frame.dts
            
        print "First pts", pts, self.stream.start_time, first_frame

        #self.nb_frames = get_frame_count(self.file, self.stream)
        self.nb_frames = self.get_frame_count()
        
        self.update_frame_range.emit(self.nb_frames)
        
        
        
        
        
class DisplayWidget(Q.QLabel):
    def __init__(self, parent=None):
        super(DisplayWidget, self).__init__(parent)
        #self.setScaledContents(True)
        self.setMinimumSize(1920/10, 1080/10)
        
        size_policy = Q.QSizePolicy(Q.QSizePolicy.Preferred, Q.QSizePolicy.Preferred)
        size_policy.setHeightForWidth(True)
        
        self.setSizePolicy(size_policy)
        
        self.setAlignment(Q.AlignHCenter| Q.AlignBottom)

        self.pixmap = None
        self.setMargin(10)
        
    def heightForWidth(self, width):
        return width * 9 / 16.0
    
    @Q.pyqtSlot(object, object)
    def setPixmap(self, img, index):
        #if index == self.current_index:
        self.pixmap = Q.QPixmap.fromImage(img)
        
        #super(DisplayWidget, self).setPixmap(self.pixmap)
        super(DisplayWidget, self).setPixmap(self.pixmap.scaled(self.size(), Q.KeepAspectRatio, Q.SmoothTransformation))
    
    def sizeHint(self):
        width = self.width()
        return Q.QSize(width, self.heightForWidth(width))
    
    def resizeEvent(self, event):
        if self.pixmap:
            super(DisplayWidget, self).setPixmap(self.pixmap.scaled(self.size(), Q.KeepAspectRatio, Q.SmoothTransformation))
        
    def sizeHint(self):
        return Q.QSize(1920/2.5,1080/2.5)
        

class VideoPlayerWidget(Q.QWidget):
    
    request_frame = Q.pyqtSignal(object)
    
    load_file = Q.pyqtSignal(object)
    
    def __init__(self, parent=None):
        super(VideoPlayerWidget, self).__init__(parent)
        self.display = DisplayWidget()
        self.timeline = Q.QScrollBar(Q.Horizontal)
        self.frame_grabber = FrameGrabber()
        
        self.frame_control = Q.QSpinBox()
        self.frame_control.setFixedWidth(100)

        self.timeline.valueChanged.connect(self.frame_changed)
        self.frame_control.valueChanged.connect(self.frame_changed)
        
        self.request_frame.connect(self.frame_grabber.request_frame)
        self.load_file.connect(self.frame_grabber.set_file)

        self.frame_grabber.frame_ready.connect(self.display.setPixmap)
        self.frame_grabber.update_frame_range.connect(self.set_frame_range)
        
        self.frame_grabber_thread = Q.QThread()
        
        self.frame_grabber.moveToThread(self.frame_grabber_thread)
        self.frame_grabber_thread.start()
        
        control_layout = Q.QHBoxLayout()
        control_layout.addWidget(self.frame_control)
        control_layout.addWidget(self.timeline)
        
        layout = Q.QVBoxLayout()
        layout.addWidget(self.display)
        layout.addLayout(control_layout)
        self.setLayout(layout)
        self.setAcceptDrops(True)
        self.timer = Q.QTimer()
        self.timer.setTimerType(Q.PreciseTimer)
        self.timer.setInterval(1000/24.)
        self.timer.timeout.connect(self.autoTick)
        self.timer.start()
    def set_file(self, path):
        #self.frame_grabber.set_file(path)
        self.load_file.emit(path)
        self.frame_changed(0)
        
    @Q.pyqtSlot(object)
    def set_frame_range(self, maximum):
        print "frame range =", maximum
        self.timeline.setMaximum(maximum)
        self.frame_control.setMaximum(maximum)
    
    def frame_changed(self, value):
        self.timeline.blockSignals(True)
        self.frame_control.blockSignals(True)
        self.timeline.setValue(value)
        self.frame_control.setValue(value)
        self.timeline.blockSignals(False)
        self.frame_control.blockSignals(False)
        #self.display.current_index = value
        self.frame_grabber.active_frame = value
        self.request_frame.emit(value)
       
    def autoTick(self):
        self.timeline.setValue(self.timeline.value()+1)
    def keyPressEvent(self, event):
        if event.key() in (Q.Key_Right, Q.Key_Left):
            direction = 1
            if event.key() == Q.Key_Left:
                direction = -1
                
            if event.modifiers() == Q.ShiftModifier:
                print 'shift'
                direction *= 10
                
            self.timeline.setValue(self.timeline.value() + direction)
                
        else:
            super(VideoPlayerWidget,self).keyPressEvent(event)
            
    def mousePressEvent(self, event):
        # clear focus of spinbox
        focused_widget = Q.QApplication.focusWidget()
        if focused_widget:
            focused_widget.clearFocus()
            
        super(VideoPlayerWidget,self).mousePressEvent(event)
        
    def dragEnterEvent(self, event):
        event.accept()
        
    def dropEvent(self, event):
        
        mime = event.mimeData()
        event.accept()
        
        
        if mime.hasUrls():
            path = str(mime.urls()[0].path())
            self.set_file(path)
    def closeEvent(self, event):
        
        self.frame_grabber.active_frame = -1
        self.frame_grabber_thread.quit()
        self.frame_grabber_thread.wait()
        
        event.accept()
        

if __name__ == "__main__":
    app = Q.QApplication(sys.argv)
    window = VideoPlayerWidget()
    test_file = sys.argv[1]
    window.set_file(test_file)                      
    window.show()
    sys.exit(app.exec_()) 

