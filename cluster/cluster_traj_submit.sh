#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

Pass this script the collection of directories with prepared subfolders.
Prepared subfolders must have ./INIT and ./TRAJ directories, as prepared with cluster_prepare.sh
This script will generate data in ./TRAJ using the .gro and .cpt in ./INIT

This job is inherently serial, though mdrun can be parallel distributed using the -P command
That argument must be passed with -P here as well.
NOTE: (*) options are mandatory and have no defaults. (+) options require one of the group and have no default.

OPTIONS:
   -h      Show this message
   -T (*)  Location of .mdp file to run at equilibrium; it is run once between folders, so this file sets the separation time between trajectory initial conditions
   -f (*)  Location of .mdp file to run for the trajectories
   -p (*)  Location of .top file to use for parameters
   -n      Number of trajectories to generate in each directory, default=100
   -P      Run with mdrun_mpi; Specifies the number of cores per job. default=1 for mdrun without MPI
   -v      Verbose (default = false)
   -1 (+)  Setup PBS for hopper@nersc
   -2 (+)  Setup PBS for cmserial on catamount@lbl (NOTE: Does not support -P, all jobs are run on single core)
   -R      READY TO SUBMIT; pass this argument to run qsub at all appropriate intervals.
EOF
}

MDP=
TIMEMDP=
TOP=
P_THREAD=1
N=100
VERBOSE=
CLUSTER=
READY=
while getopts “hT::f:p:n:P:v:1::R2” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         T)
             TIMEMDP=$OPTARG
             ;;
	 f)
             MDP=$OPTARG
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
	 1)
	     CLUSTER="HOPPER"
	     ;;
	 2)
	     CLUSTER="CATAMOUNT"
 	     ;;
	 R)
	     READY=1
	     ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z $MDP ]] || [[ -z $TIMEMDP ]] || [[ -z $TOP ]] || [[ -z $CLUSTER ]]
then
     echo "REQUIRED INPUT: -f $MDP, -T $TIMEMDP, -p $TOP, CLUSTER: $CLUSTER"
     usage
     exit 1
fi

shift $(( OPTIND - 1 ))

INITWD=$(pwd)
MPISUFFIX=
if [ $P_THREAD -gt 1 ]; then
	MPISUFFIX="_mpi"
fi

if [ $CLUSTER = "HOPPER" ]; then

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
		echo "#PBS -q thruput" >> temp_submit.pbs

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
fi



if [ $CLUSTER = "CATAMOUNT" ]; then
	if [ $P_THREAD -gt 1 ]; then
		echo "ERROR: Catamount cluster does not have allow for threading in multi-tenancy serial mode, do not use -P option."
	else
		for dir in $@; do
			cd $dir
			FULL=$(ls INIT | grep "\.cpt$" | head -n 1)
			echo "FULL: " $FULL
			BASE=${FULL//.cpt/}
			echo "BASE: " $BASE
		
		# GENERATE THE SCRIPT
			echo "#PBS -N gmx_traj_$BASE" > temp_submit.pbs
			echo "#PBS -q cm_serial" >> temp_submit.pbs
			echo "#PBS -l nodes=1:ppn=1:cmserial" >> temp_submit.pbs
			#echo "#PBS -l walltime=01:00:00" >> temp_submit.pbs
			echo "#PBS -j oe" >> temp_submit.pbs
			
			echo 'cd $PBS_O_WORKDIR' >> temp_submit.pbs
			echo "module load gromacs" >> temp_submit.pbs
			echo "export GMX_MAXBACKUP=0" >> temp_submit.pbs
			echo " " >> temp_submit.pbs
		
			echo "for (( num=1 ; num <= $N ; num++)) ; do" >> temp_submit.pbs
			# Run the trajectory for an arbitrary time
			echo '	cd $PBS_O_WORKDIR' >> temp_submit.pbs
			echo "	grompp -f $MDP -p $TOP -c INIT/$BASE."'$num'".gro -t INIT/$BASE."'$num'".cpt -o TRAJ/traj"'$num'" -maxwarn 1" >> temp_submit.pbs
			echo "	cd TRAJ" >> temp_submit.pbs
			echo "	mdrun -nt 1 -v -deffnm traj"'$num'" >& qsub_mdrun.log" >> temp_submit.pbs
	
			# Run the mini-spacer for an arbitrary time to make sure we continue to sample the equilibrium distribution of initial configs
			echo " " >> temp_submit.pbs
			echo '	cd $PBS_O_WORKDIR' >> temp_submit.pbs
			echo "	grompp -f $TIMEMDP -p $TOP -c INIT/$BASE."'$num'".gro -t INIT/$BASE."'$num'".cpt -o INIT/$BASE."'$(($num+1))'" -maxwarn 1" >> temp_submit.pbs
			echo "	cd INIT" >> temp_submit.pbs
			echo "	mdrun -nt 1 -v -deffnm $BASE."'$(($num+1))'" >& qsub_mdrun.log" >> temp_submit.pbs
			echo "done" >> temp_submit.pbs
		# SUBMIT THE SCRIPT
			
			if [ $READY ]; then
				qsub temp_submit.pbs
			fi

			cd -
		done
	fi
fi
