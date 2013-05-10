#!/usr/bin/env python2.7
import shlex
import numpy as np
import argparse
import cPickle
from pylab import *
from sys import exit

parser = argparse.ArgumentParser(description='Average over many .xvg energy trajectory files to get the average E(t) and S(t).')
parser.add_argument('-f', dest='fname', type=str, help='The gromacs energy .xvg file to run autocorrelation on')
parser.add_argument('-to', dest='start_time', type=float, default=0, help='The time to start at, if part of the trajectory should be ignored. In no particular units, check the file for the unit scheme')
parser.add_argument('-tf', dest='end_time', type=float, default=0, help='The time to end at, if part of the trajectory should be ignored. In no particular units, check the file for their unit scheme')
parser.add_argument('-p', dest='lenplot', type=int, default=0, help='The number of data points to plot. Should be passed with --pklplot to allow pklplot to plot anything')
parser.add_argument('-pkl', dest='pickle_name', type=str, default='', help='Add this argument to pickle the correlation function. Include the extension.')
parser.add_argument('--pklplot', dest='pickle_in', type=str, default='', help='For plotting old pickles. Skips the main functions, and just plots the pickle.')


args = parser.parse_args()
if (args.pickle_in != ''):
	pkl_in = open(args.pickle_in, 'r')
	crlf = cPickle.load(pkl_in)
	plot(crlf[0:args.lenplot])
	show()
	exit()
istimelimit = 0;
if (args.end_time != 0):
	istimelimit = 1


# MAIN FUNCTION
e_t = list()
time = list()

print 'NEW FILE: ' + args.fname
n = 0
with open(args.fname, 'r') as f:
	for line in f:
		if (line[0] != '#' and line[0] != '@'):
			cols = shlex.split(line);
			if (float(cols[0]) > args.start_time): 
				if (istimelimit and (args.end_time <= float(cols[0]))):
					break
				e_t.append(float(cols[1]))
				time.append(float(cols[0]))
				n=n+1
				print n
	e_t = np.array(e_t)
	time= np.array(time)

de_t = e_t - np.mean(e_t)

print "Computing Correlation..."
crlf=np.correlate(de_t, de_t,mode='full')[len(de_t)-1:]

# Real autocorrelation
#crlf2=np.zeros(len(e_t))
#for i in range(len(e_t)):
#	print i
#	for j in range(i,len(e_t)):
#		crlf2[j-i] = crlf2[j-i] + e_t[i] * e_t[j]

print "Normalizing Correlation..."
for i in range(len(crlf)):
	crlf[i] = crlf[i] / (len(crlf) - i)

normal = crlf[0]
for i in range(len(crlf)):
	crlf[i] = crlf[i] / normal


if (args.pickle_name != ""):
	print "Pickle requested!"
	pkl_out = open(args.pickle_name, 'w')
	cPickle.dump(crlf, pkl_out)
	pkl_out.close()


print len(crlf)
print len(time)
if (args.lenplot > 0):
	plot(time[0:args.lenplot], crlf[0:args.lenplot])
	show()


