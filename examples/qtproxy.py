import sys

from PyQt5 import QtCore, QtGui, QtOpenGL, QtMultimedia, QtWidgets

try:
    str
except NameError:
    str = str
class QtProxy(object):

    def __init__(self, *modules):
        self._modules = list(modules)

    def __getattr__(self, base_name):
        for i,mod in enumerate(self._modules):
            if isinstance ( mod, str ):
                self._modules[i] = __import__( mod )
                if "." in mod:
                    for component in mod.split(".")[1:]:
                        self._modules[i] = getattr(self._modules[i],component)
                mod = self._modules[i]
            for prefix in ('Q', '', 'Qt'):
                name = prefix + base_name
                obj = getattr(mod, name, None)
                if obj is not None:
                    setattr(self, base_name, obj)
                    return obj
        raise AttributeError(base_name)

Q = QtProxy ( *(
    "PyQt5.Qt",
    "PyQt5.QtWidgets",
    "PyQt5.QtGui",
    "PyQt5.QtCore",
     QtCore.Qt,
    "PyQt5.QtOpenGL",
    "PyQt5.QtNetwork",
    "PyQt5.QtMultimedia",
    "PyQt5.QtMultimediaWidgets",
    "PyQt5.QtQml",
    "PyQt5.QtQuick",
    "PyQt5.QtQuickWidgets",
    "PyQt5.QtSql",
    "PyQt5.QtXml",
    "PyQt5.QtSvg",
    "PyQt5.QtSensors",
    "PyQt5.QtPositioning",
    "PyQt5.QtSerialPort",
    "PyQt5.QtXmlPatterns",
    "PyQt5.QtWebSockets",
    "PyQt5.QtWebKit",
    "PyQt5.QtWebKitWidgets")
    )
