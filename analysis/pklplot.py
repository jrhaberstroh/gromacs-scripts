#!/usr/bin/env python2.7
import cPickle
import argparse
import numpy as np
from pylab import *

parser = argparse.ArgumentParser(description='Plot a .pkl file with default plotting parameters.')
parser.add_argument('-f', dest='pkl_name', type=str, help='The file to be plotted.')


args = parser.parse_args()

pkl_in = open(args.pkl_name, 'r')
xyplot = cPickle.load(pkl_in)
plot(xyplot[0], xyplot[1])
show()
exit()
