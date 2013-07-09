#!/usr/bin/env python2.7
import argparse
import cPickle
import pylab as plt
import numpy as np


def plotCt(yplot, args):
	plt.xlabel(args.xlabel)
	plt.ylabel(args.ylabel)
	plt.title(args.title)

	xaxis=[]
	yaxis=[]
	try:
		xaxis= np.array(xrange(0, args.tf)) * args.xrescale
		yaxis= yplot[0:args.tf]
	except:
		xaxis= np.array(xrange(0, len(yplot) )) *args.xrescale
		yaxis= yplot

	plt.plot(xaxis, yaxis, linestyle='None',marker='h', markersize=3, markerfacecolor=args.color)
	
	if not (args.multi == None):
		out_dat = (xaxis, yaxis, args)
		pkl_out = open(str(args.multi)+".mpt", 'w')
		print "Saved for multiplot in " + str(args.multi)+".mpt"
		cPickle.dump(out_dat, pkl_out)
		pkl_out.close()

	plt.show()
	exit()

parser = argparse.ArgumentParser(description='Average over many .xvg energy trajectory files to get the average E(t) and S(t).')
parser.add_argument('pkl_name', help='Set the path to the cPickle to plot.')
parser.add_argument('-mode', type=str, default="CT", help='The type of data being processed. Currently, the valid argument is ST (default).')
parser.add_argument('-tf', type=int, help='Set the number of datapoints to plot')
parser.add_argument('-ylabel', type=str, default="", help='The x-axis for the plot.')
parser.add_argument('-xlabel', type=str, default="", help='The y-axis for the plot.')
parser.add_argument('-xrescale', type=float, default=1, help='Factor to apply to the x-axis.')
parser.add_argument('-color', type=str, default="black", help='Color to plot in.')
parser.add_argument('-title', type=str, default="", help='The name of the plot.')
parser.add_argument('-multi', type=int, default=None, help='The multi-plot to output to.')
args = parser.parse_args()


pkl_in = open(args.pkl_name, 'r')
yplot = cPickle.load(pkl_in)
pkl_in.close()

if (args.mode == "CT"):
	plotCt(yplot, args)
