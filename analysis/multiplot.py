#!/usr/bin/env python2.7
import cPickle
import argparse
import numpy as np
from pylab import *


parser = argparse.ArgumentParser(description='Plot a .pkl file with default plotting parameters.')
parser.add_argument('pkl_names', nargs="+", help='The file to be plotted.')
parser.add_argument('-ylabel', type=str, default="", help='The x-axis for the plot.')
parser.add_argument('-xlabel', type=str, default="", help='The y-axis for the plot.')
parser.add_argument('-title', type=str, default="", help='The name of the plot.')
args = parser.parse_args()


plt.hold(True)
for pkl_name in args.pkl_names:
	pkl_in = open(pkl_name, 'r')
	print "Opened file " + pkl_name
	plotdat = cPickle.load(pkl_in)
	pkl_in.close()
	plt.plot(plotdat[0], plotdat[1], marker='h', markersize=3, mfc=plotdat[2].color, mew=0, c=plotdat[2].color, label=plotdat[2].title)
	plt.legend()
	print len(plotdat[0])

plt.xlabel(args.xlabel)
plt.ylabel(args.ylabel)
plt.title(args.title)

plt.show()
