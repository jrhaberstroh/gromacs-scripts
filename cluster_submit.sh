#!/bin/bash
# Pass this script the collection of directories with prepared subfolders.
# Prepared subfolders have ./INIT and ./TRAJ directories.
# This script will generate data in ./TRAJ using the .cpt in ./INIT
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
   -T (*)  Location of .mdp file to run at equilibrium; it is run once between folders, so this file sets the separation time between trajectory initial conditions
   -f (*)  Location of .mdp file to run for the trajectories
   -p (*)  Location of .top file to use for parameters
   -n      Number of trajectories to generate, default=100
   -P      Run with mdrun_mpi; Specifies the number of cores per job. default=1 for mdrun without MPI
   -v      Verbose (default = false)
EOF
}

MDP=
TIMEMDP=
TOP=
P_THREAD=1
N=100
VERBOSE=
while getopts “h:T:f:p:n:P:v” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
	 f)
             MDP=$OPTARG
             ;;
         T)
             TIMEMDP=$OPTARG
             ;;
       	 p)
             TOP=$OPTARG
             ;;
	 n)
	     N=$OPTARG
	     ;;
	 P)
	     P_THREAD=$OPTARG
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

if [[ -z $MDP ]] || [[ -z $TIMEMDP ]] || [[ -z $TOP ]]
then
     usage
     exit 1
fi

shift $(( OPTIND - 1 ))

INITWD=$(pwd)
MDP=$INITWD/$MDP
TOP=$INITWD/$TOP


for dir in $@; do
	cd $INITWD/$dir
	FULL=$(ls INIT | grep "\.cpt$" | head -n 1)
	echo "FULL: " $FULL
	BASE=${FULL//.cpt/}
	echo "BASE: " $BASE

# GENERATE THE SCRIPT
	echo "#PBS -N gmx_traj_$BASE" > temp_submit.pbs
	echo "#PBS -l mppwidth=$P_THREAD" >> temp_submit.pbs
	echo "#PBS -l walltime=01:00:00" >> temp_submit.pbs
	echo "#PBS -j oe" >> temp_submit.pbs
	echo "cd $INITWD/$dir" >> temp_submit.pbs
	echo "module load gromacs" >> temp_submit.pbs
	echo " " >> temp_submit.pbs

	echo "for (( num=1 ; num <= $N ; num++)) ; do" >> temp_submit.pbs
	echo "aprun -n $P_THREAD grompp_mpi -f $MDP -p $TOP -c INIT/$BASE.gro -t INIT/$BASE.cpt -o TRAJ/traj" >> temp_submit.pbs
	echo "cd $INITWD/$dir/TRAJ" >> temp_submit.pbs
	echo "aprun -n $P_THREAD mdrun_mpi -v -deffnm traj >& qsub_mdrun.log" >> temp_submit.pbs

	echo " " >> temp_submit.pbs
	echo "cd $INITWD/$dir" >> temp_submit.pbs
	echo "aprun -n $P_THREAD grompp_mpi -f $TIMEMDP -p $TOP -c INIT/$BASE.gro -t INIT/$BASE.cpt -o INIT/$BASE" >> temp_submit.pbs
	echo "cd $INITWD/$dir/INIT" >> temp_submit.pbs
	echo "aprun -n $P_THREAD mdrun_mpi -v -deffnm $BASE >& qsub_mdrun.log" >> temp_submit.pbs
	echo "done" >> temp_submit.pbs
# SUBMIT THE SCRIPT

	#qsub temp_submit.pbs
done
