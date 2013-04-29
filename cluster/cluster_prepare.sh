#!/bin/bash
#PBS -N prep_traj_submit
#PBS -q debug
#PBS -l walltime=00:30:00
#PBS -j oe
#PBS -V

usage()
{
cat << EOF
usage: $0 options

This script sets up a collection of directories to submit many serial gromacs jobs on a cluster.
This job is inherently serial, though mdrun can be parallel distributed.
If MPI is wanted, qsub must be called:
>> qsub -l mppwidth=NUM_CORES
That argument must be passed with -P here as well.
NOTE: (*) options are mandatory and have no defaults.

OPTIONS:
   -h      Show this message
   -n (*)  Number of cores to prepare for, will also be the number of directories spawned
   -f (*)  Location of .mdp file to run at equilibrium; it is run once between folders, so this file sets the separation time between cores
   -c (*)  Location of .gro (or .pdb) file to use for the configuration
   -t (*)  Location of .cpt file (from equilibration, usually)
   -p (*)  Location of .top file to use for parameters
   -P      Run with mdrun_mpi; Specifies the number of cores available. default=0 for mdrun without MPI
   -b      Folder basename, default is CORE
   -v      Verbose (default = false)
EOF
}



CORES=
MDP=
GRO=
CPT=
TOP=
PLL=0
BASE='CORE'
VERBOSE=
while getopts “h:n:f:c:t:p:P:b:v” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         n)
             CORES=$OPTARG
             ;;
         f)
             MDP=$OPTARG
             ;;
         c)
             GRO=$OPTARG
             ;;
       	 t)
             CPT=$OPTARG
             ;;
       	 p)
             TOP=$OPTARG
             ;;
	 P)
	     PLL=$OPTARG
	     ;;
	 b)
	     BASE=$OPTARG
	     ;;
         v)
             VERBOSE=1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z $MDP ]] || [[ -z $CORES ]] || [[ -z $TOP ]] || [[ -z $GRO ]] || [[ -z $CPT ]]
then
     usage
     exit 1
fi

GRO=$(pwd)/$GRO
TOP=$(pwd)/$TOP
CPT=$(pwd)/$CPT
MDP=$(pwd)/$MDP


echo $CORES
echo $TIME

#mdrun $CORES times. Make a new directory for each.
DIGITS=${#CORES}
PREVIOUS=
for CTR in $(eval echo {1..$CORES})
do
	CTR_DIGITS=${#CTR}
	printf -v PRE "%$(echo $DIGITS)d" $CTR
	STR=${PRE// /'0'}
	mkdir $BASE$STR #Allows ls to order cores numerically by using leading zeros.
	cd $BASE$STR 
	mkdir INIT
	mkdir TRAJ
	cd INIT
	if [[ -z $PREVIOUS ]]
		then grompp -f $MDP -c $GRO -p $TOP -t $CPT -o init$STR.tpr
	else
		grompp -f $MDP -c $GRO -p $TOP -t $PREVIOUS -o init$STR.tpr
	fi
		
	touch init$STR.tpr
	if [ $PLL -eq 0 ]
		then mdrun -v -deffnm init$STR
	else
		aprun -n $PLL mdrun_mpi >& test.log
	fi
	PREVIOUS=$(pwd)/init$STR.cpt
	cd ../..
done
