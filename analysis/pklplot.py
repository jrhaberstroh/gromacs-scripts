#!/usr/bin/env python2.7
import cPickle
import argparse
import numpy as np
from pylab import *

def plotSt(xyplot, args):
	if (args.STmax == None):
		args.STmax = xyplot[1][0]
		print "Setting STmax to " + str(args.STmax)
	if (args.STmin == None):
		args.STmin = xyplot[1][-1]
		print "Setting STmin to " + str(args.STmin)
	xyplot[1] -= args.STmin
	xyplot[1] /= (args.STmax - args.STmin)
	plt.xlabel(args.xlabel)
	plt.ylabel(args.ylabel)
	plt.title(args.title)
	xyplot[0] *= args.xrescale

	if not (args.multi == None):
		out_dat = (xyplot[0], xyplot[1], args)
		pkl_out = open(str(args.multi)+".mpt", 'w')
		print "Saved for multiplot in " + str(args.multi)+".mpt"
		cPickle.dump(out_dat, pkl_out)
		pkl_out.close()

	plot(xyplot[0], xyplot[1], linestyle='None',marker='h', markersize=3, markerfacecolor=args.color)
	plt.ylim([0,1])
	plt.show()
	exit()


parser = argparse.ArgumentParser(description='Plot a .pkl file with default plotting parameters.')
parser.add_argument('pkl_name', help='The file to be plotted.')
parser.add_argument('-mode', type=str, default="ST", help='The type of data being processed. Currently, the valid argument is ST (default).')
parser.add_argument('-STmin', type=float, default=None, help='The peak value for computing S(t).')
parser.add_argument('-STmax', type=float, default=None, help='The final value for computing S(t).')
parser.add_argument('-ylabel', type=str, default="", help='The x-axis for the plot.')
parser.add_argument('-xlabel', type=str, default="", help='The y-axis for the plot.')
parser.add_argument('-xrescale', type=float, default=1, help='Factor to apply to the x-axis.')
parser.add_argument('-color', type=str, default="black", help='Color to plot in.')
parser.add_argument('-title', type=str, default="", help='The name of the plot.')
parser.add_argument('-multi', type=int, default=None, help='The multi-plot to output to.')
args = parser.parse_args()


pkl_in = open(args.pkl_name, 'r')
xyplot = cPickle.load(pkl_in)
pkl_in.close()

if (args.mode == "ST"):
	plotSt(xyplot, args);




