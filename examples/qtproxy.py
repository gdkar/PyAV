import sys

from PyQt5 import QtCore, QtGui,  QtMultimedia, QtWidgets, Qt


class QtProxy(object):

	def __init__(self, *modules):
		self._modules = modules
	def __getattr__(self, base_name):
		for mod in self._modules:
			for prefix in ("",'Q', '', 'Qt'):
				name = prefix + base_name
				obj = getattr(mod, name, None)
				if obj is not None:
					setattr(self, base_name, obj)
					return obj
		raise AttributeError(base_name)

Q = QtProxy(QtGui, QtCore, QtCore.Qt,  QtMultimedia, QtWidgets, Qt)
