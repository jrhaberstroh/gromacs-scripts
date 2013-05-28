#!/usr/bin/env python
import shlex
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
import numpy as np
import argparse
import cPickle

parser = argparse.ArgumentParser(description='Average over many .xvg energy trajectory files to get the average E(t) and S(t).')
parser.add_argument('--files', dest='file_list', nargs='+', type=str, help='A collection of all of the files to be averaged over')
parser.add_argument('-n', dest='total_time', type=int, default=0, help='The total number of time steps to average over. Overwritten by the number of time steps in the first file opened if this is smaller.')
parser.add_argument('-pkl', dest='pickle_name', type=str, default='', help='The name of the pickle file to send the output into.')
parser.add_argument('-Ef', dest='final_E', type=str, default=None, help='The asymptotic value for the trajectories. E0, the initial value, is selected from the average')

args = parser.parse_args()
istimelimit = 0;
if (args.total_time != 0):
	istimelimit = 1


e_t = list()
time = list()
S_t = []

print "Beginning the E_av(t) calculation..."
file_count = 0;
try: 
	for fname in args.file_list:
		print 'NEW FILE: ' + fname
		n = 0
		with open(fname, 'r') as f:
			e_t_temp = list()
			# Build the data array with comments ignored
			for line in f:
				if (istimelimit and n >= args.total_time):
					break
				if (line[0] != '#' and line[0] != '@'):
					cols = shlex.split(line);
					n = n+1
					if (file_count == 0):
						e_t.append(float(cols[1]))
						time.append(float(cols[0]))
					else:
						e_t_temp.append(float(cols[1]))
			# Add the data to the sum
			if (file_count == 0):
				e_t = np.array(e_t)
				time= np.array(time)
			else:
				e_t = e_t + np.array(e_t_temp)
			file_count = file_count + 1;
	
	e_t = np.array(e_t)
	e_t /= file_count
	time = np.array(time)
	if not args.final_E:
		plt.plot(time, e_t)
		plt.show(block=False)
		while not args.final_E:
			try:
				args.final_E = -66.67#float(raw_input("What is your estimate for the asymptotic energy value?"))
			except ValueError:
				print 'Invalid number'
		plt.close()
	
	S_t = e_t - args.final_E
	S_t /= e_t[0] - args.final_E
	print [e_t, time]
except TypeError:
	print "TypeError: Either no files were passed or bad types were passed, skipping E_av(t) computation."
except IndexError:
	print "IndexError: Something has gone wrong with processing indexes in the main function; aborting code"


spacing = .1
minval = -5
maxval = 6
bin_gen = np.arange(minval,maxval,spacing)
bin_gen2= np.reshape(bin_gen, (1,len(bin_gen)))
len_gen = np.ones((len(time),1))
bins = np.dot(len_gen, bin_gen2)
#print bins
hist = np.zeros((len(time), len(bin_gen)))
#print hist

print "Beginning the histogram calculation..."
try: 
	for fname in args.file_list:
		print 'NEW FILE: ' + fname
		n = 0
		with open(fname, 'r') as f:
			e_t_temp = list()
			# Build the data array with comments ignored
			for line in f:
				if (istimelimit and n >= args.total_time):
					break
				if (line[0] != '#' and line[0] != '@'):
					cols = shlex.split(line);
					n = n+1
					if (file_count == 0):
						e_t.append(float(cols[1]))
						time.append(float(cols[0]))
					else:
						e_t_temp.append(float(cols[1]))
			# Bin the data
			e_t_temp = np.array(e_t_temp)
			e_t_temp -= args.final_E
			e_t_temp /= e_t[0] - args.final_E
			for i, e_val in enumerate(e_t_temp):
				try:
					hist[i][int((e_val - minval) / spacing)] += 1
				except IndexError:
					print "Encountered value too extreme for histogram,", e_val


	
except TypeError:
	print "TypeError: Either no files were passed or bad types were passed, skipping histogram computation"
except IndexError:
	print "IndexError: Something has gone wrong with processing indexes in the main function; aborting code"

print "plotting the image:"	
imgplot = plt.imshow(hist.T, origin='lower', cmap='binary')
ax = plt.gca()
plt.xticks(np.arange(1,101,10),time[ : :10])
plt.yticks(np.arange(1,110,10), np.arange(minval,maxval,spacing)[ : :10])
print len(time)
print hist.shape
plt.show()

#print [e_t / file_count, time]
print "Done with processing"

if (args.pickle_name != ""):
	print "Pickle requested!"
	pkl_out = open("et_"+args.pickle_name, 'w')
	cPickle.dump([time, e_t/file_count], pkl_out)
	pkl_out.close()
	pkl_out = open("hist_"+args.pickle_name, 'w')
	cPickle.dump([time, bins, hist], pkl_out)
	pkl_out.close()
