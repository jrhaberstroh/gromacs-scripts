#!/usr/bin/env python2.7
import argparse
import cPickle
import pylab as plt

parser = argparse.ArgumentParser(description='Average over many .xvg energy trajectory files to get the average E(t) and S(t).')
parser.add_argument('pkl_name', help='Set the path to the cPickle to plot.')
parser.add_argument('-tf', dest='lenplot', type=int, help='Set the number of datapoints to plot')
args = parser.parse_args()

pkl_in = open(args.pkl_name, 'r')
crlf = cPickle.load(pkl_in)
try:
	plt.plot(crlf[0:args.lenplot])
except:
	plt.plot(crlf)
plt.show()
