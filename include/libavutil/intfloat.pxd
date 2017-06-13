##
#  Copyright (c) 2011 Mans Rullgard
#
#  This file is part of FFmpeg.
#
#  FFmpeg is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  FFmpeg is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with FFmpeg; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
# /


from libc.stdint cimport *
cdef extern from "libavutil/intfloat.h" nogil:
    cdef union av_intfloat32:
        uint32_t i;
        float    f;

    cdef union av_intfloat64:
        uint64_t i;
        double   f;

cdef inline float av_int2float(uint32_t i):
    cdef av_intfloat32 v
    v.i = i
    return v.f

cdef inline uint32_t av_float2int(float f):
    cdef av_intfloat32 v
    v.f = f
    return v.i
cdef inline double av_int2double(uint64_t i):
    cdef av_intfloat64 v
    v.i = i
    return v.f

cdef inline uint64_t av_double2int(double f):
    cdef av_intfloat64 v
    v.f = f
    return v.i
#endif /* AVUTIL_INTFLOAT_H */
