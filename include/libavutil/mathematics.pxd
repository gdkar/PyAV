##
# copyright (c) 2005-2012 Michael Niedermayer <michaelni@gmx.at>
#
# This file is part of FFmpeg.
#
# FFmpeg is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# FFmpeg is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with FFmpeg; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
##

#include <stdint.h>
#include <math.h>
#include "attributes.h"
#include "rational.h"
#include "intfloat.h"


##
# @addtogroup lavu_math
# @{
#
from libc.stdint cimport *
from libc.stddef cimport *
from libc.stdio  cimport *
from libc.stdlib cimport *

#from rational cimport *
#from intfloat cimport *
cdef extern from "libavutil/mathematics.h" nogil:
    cdef enum AVRounding:
        AV_ROUND_ZERO     = 0 ##< Round toward zero.
        AV_ROUND_INF      = 1 ##< Round away from zero.
        AV_ROUND_DOWN     = 2 ##< Round toward -infinity.
        AV_ROUND_UP       = 3 ##< Round toward +infinity.
        AV_ROUND_NEAR_INF = 5 ##< Round to nearest and halfway cases away from zero.
        AV_ROUND_PASS_MINMAX = 8192 ##< Flag to pass INT64_MIN/MAX through instead of rescaling, this avoids special cases for AV_NOPTS_VALUE

##
# Compute the greatest common divisor of a and b.
#
# @return gcd of a and b up to sign; if a >= 0 and b >= 0, return value is >= 0;
# if a == 0 and b == 0, returns 0.
#
    cdef int64_t av_gcd(int64_t a, int64_t b);

##
# Rescale a 64-bit integer with rounding to nearest.
# A simple a*b/c isn't possible as it can overflow.
#
    cdef int64_t av_rescale(int64_t a, int64_t b, int64_t c) ;

##
#  Rescale a 64-bit integer with specified rounding.
#  A simple a*b/c isn't possible as it can overflow.
#
#  @return rescaled value a, or if AV_ROUND_PASS_MINMAX is set and a is
#          INT64_MIN or INT64_MAX then a is passed through unchanged.
# /
    cdef int64_t av_rescale_rnd(int64_t a, int64_t b, int64_t c, AVRounding);

##
#  Rescale a 64-bit integer by 2 rational numbers.
# /
    cdef int64_t av_rescale_q(int64_t a, AVRational bq, AVRational cq);

##
#  Rescale a 64-bit integer by 2 rational numbers with specified rounding.
#
#  @return rescaled value a, or if AV_ROUND_PASS_MINMAX is set and a is
#          INT64_MIN or INT64_MAX then a is passed through unchanged.
# /
    cdef int64_t av_rescale_q_rnd(int64_t a, AVRational bq, AVRational cq,AVRounding) ;

##
#  Compare 2 timestamps each in its own timebases.
#  The result of the function is undefined if one of the timestamps
#  is outside the int64_t range when represented in the others timebase.
#  @return -1 if ts_a is before ts_b, 1 if ts_a is after ts_b or 0 if they represent the same position
# /
    cdef int av_compare_ts(int64_t ts_a, AVRational tb_a, int64_t ts_b, AVRational tb_b);

##
#  Compare 2 integers modulo mod.
#  That is we compare integers a and b for which only the least
#  significant log2(mod) bits are known.
#
#  @param mod must be a power of 2
#  @return a negative value if a is smaller than b
#          a positive value if a is greater than b
#          0                if a equals          b
# /
    cdef int64_t av_compare_mod(uint64_t a, uint64_t b, uint64_t mod);

##
#  Rescale a timestamp while preserving known durations.
#
#  @param in_ts Input timestamp
#  @param in_tb Input timebase
#  @param fs_tb Duration and# last timebase
#  @param duration duration till the next call
#  @param out_tb Output timebase
# /
    cdef int64_t av_rescale_delta(
        AVRational in_tb
      , int64_t in_ts
      ,  AVRational fs_tb
      , int duration
      , int64_t* last
      , AVRational out_tb);

##
#  Add a value to a timestamp.
#
#  This function guarantees that when the same value is repeatly added that
#  no accumulation of rounding errors occurs.
#
#  @param ts Input timestamp
#  @param ts_tb Input timestamp timebase
#  @param inc value to add to ts
#  @param inc_tb inc timebase
# /
    cdef int64_t av_add_stable(
        AVRational ts_tb
      , int64_t ts
      , AVRational inc_tb
      , int64_t inc);


    ##
#  @}
# /

#endif /* AVUTIL_MATHEMATICS_H# /
