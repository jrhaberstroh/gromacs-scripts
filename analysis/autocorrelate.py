#!/usr/bin/env python2.7
import shlex
import numpy as np
import argparse
import cPickle
from pylab import *
from sys import exit

parser = argparse.ArgumentParser(description='Average over many .xvg energy trajectory files to get the average E(t) and S(t).')
# Positional arguments
parser.add_argument('xvg_in', dest='fname', help='The gromacs energy .xvg file to run autocorrelation on')
parser.add_argument('save', dest='pickle_name', help='Add this argument to save the correlation function (as a cPickle object). This script stores the result of autocorrelation with the time axis in units (usually ps in gromacs). There is no default file extension.')
# Optional arguments
parser.add_argument('-to', dest='start_time', type=float, default=0, help='The time to start at, if part of the trajectory should be ignored. In the units from xvg_in (usually ps in gromacs).')
parser.add_argument('-tf', dest='end_time', type=float, default=0, help='The time to end at, if part of the trajectory should be ignored. In the units from xvg_in (usually ps in gromacs).')
parser.add_argument('-p', dest='lenplot', type=int, default=0, help='The number of data points to plot. Should be passed with --pklplot to allow pklplot to plot anything')
parser.add_argument('-2', dest='half', action='store_true', help='Split the data in half and plot the two halves autocorrelated separately in addition to doing the full autocorrelation (primarily for error checking purposes). Saved half-files will have appended to their file names ".1" and ".2".')

args = parser.parse_args()
istimelimit = 0;
if (args.end_time != 0):
	istimelimit = 1

# MAIN FUNCTION
e_t = list()
time = list()

print 'Computing autocorrelation of: ' + args.fname
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

if half:
	print "Computing Halves"
	half1 = np.array(e_t[0:len(e_t)/2])
	half2 = np.array(e_t[len(e_t)/2:len(e_t)])
	dhalf1= half1 - np.mean(half1)
	dhalf2= half2 - np.mean(half2)
	crlf1 = np.correlate(dhalf1, dhalf1, mode='full')[len(dhalf1)-1:]
	crlf2 = np.correlate(dhalf2, dhalf2, mode='full')[len(dhalf2)-1:]
	if (args.pickle_name != ""):
		print "Pickle requested! Pickling the halves!"
		pkl_out = open(args.pickle_name + ".1", 'w')
		cPickle.dump(crlf1, pkl_out)
		pkl_out.close()
		pkl_out = open(args.pickle_name + ".2", 'w')
		cPickle.dump(crlf2, pkl_out)
		pkl_out.close()

print "Computing Correlation..."
de_t = e_t - np.mean(e_t)
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
	cPickle.dump((time,crlf), pkl_out)
	pkl_out.close()


print len(crlf)
print len(time)
if (args.lenplot > 0):
	plot(time[0:args.lenplot], crlf[0:args.lenplot])
	show()


