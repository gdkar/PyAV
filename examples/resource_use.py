

import argparse
import resource
import gc
import av
parser = argparse.ArgumentParser()
parser.add_argument('-c', '--count', type=int, default=5)
parser.add_argument('-f', '--frames', type=int, default=100)
parser.add_argument('--print', dest='print_', action='store_true')
parser.add_argument('--to-rgb', action='store_true')
parser.add_argument('--to-image', action='store_true')
parser.add_argument('--gc', '-g', action='store_true')
parser.add_argument('input')
args = parser.parse_args()

def format_bytes(n):
    order = 0
    sgn = n / abs(n) if n else 1
    n = abs(n)
    while n > 1024:
        order += 1
        n //= 1024
    return '%d%sB' % (sgn * n, ('', 'k', 'M', 'G', 'T', 'P')[order])
usage = []
gbefore = resource.getrusage(resource.RUSAGE_SELF)
for round_ in range(args.count):
    print(('Round %d/%d:' % (round_ + 1, args.count)))
    if args.gc:
        gc.collect()
    before = resource.getrusage(resource.RUSAGE_SELF)
    fh = av.open(args.input)
    vs = next(s for s in fh.streams if s.type == 'video')
    fi = 0
    fl = list()
    ims = list()
    for packet in fh.demux([vs]):
        for frame in packet.decode():
            if frame:
                if args.print_:print(frame)
                if args.to_rgb:ims.append((frame.to_rgb()))
                if args.to_image:ims.append(frame.to_image())
                fi += 1
                fl.append(frame)
        if len(fl) > args.frames:
            break
    after = resource.getrusage(resource.RUSAGE_SELF)
    usage.append((before,after))
    fl.clear()
    ims.clear()
    frame = packet = fh = vs = None
gafter = resource.getrusage(resource.RUSAGE_SELF)
usage.append((gbefore,gafter))
for i,(before,after) in enumerate(usage):
    print(('%s (%s)' % (format_bytes(after.ru_maxrss), format_bytes(after.ru_maxrss - before.ru_maxrss))))
