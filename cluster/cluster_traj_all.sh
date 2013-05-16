#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

This script will first generate a job that spawns some number of directories spaced by a large spacer. It will then generate an array hold-job to follow up the first job, a job that runs individual trajectories off of many cores, one for each spawned trajectory.

It 

OPTIONS:
   -h      Show this message
   -N [*]  Naming scheme; kept consistent between folders & jobs
   -T (*)  Location of long .mdp file to run at equilibrium; it is run once between folders.
   -t [*]  Location of short .mdp file to run at equilibrium; it is run once between trajectories in a given folder.
   -f (*)  Location of .mdp file to run as a trajectory; alternates running with -t.
   -c [*]  Location of .gro file to use as initial configuration
   -p (*)  Location of .top file to use for parameters
   -t [*]  Location of .cpt file to use for initial checkpoint
   -N      Number of folders to generate (default=100)
   -n      Number of trajectories to generate in each directory (default=100)
   -1 (+)  Setup PBS for hopper@nersc
   -2 (+)  Setup PBS for cmserial on catamount@lbl (NOTE: Does not support -P, all jobs are run on single core)
   -R      READY TO SUBMIT; pass this argument to run qsub at all appropriate intervals. Without this flag, only .pbs files will be generated.
   -p      Number of processors to request for any instance of the jobs (cluster default)
   -W      Number of warnings allowed by grompp (default=gromacs-default)
   -w      Walltime (cluster default)
   
EOF
}

NAME=
FOLDMDP=
STEPMDP=
TRAJMDP=
GRO=
CPT=
TOP=
ntraj=100
nfold=100
VERBOSE=
CLUSTER=
READY=
P_THREAD=
WALL=
WARN=
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
	echo "Not yet built for Hopper"
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
			echo "module load gromacs/4.6" >> temp_submit.pbs
			echo "export GMX_MAXBACKUP=-1" >> temp_submit.pbs
			echo " " >> temp_submit.pbs


			# Run the mini-spacer for an arbitrary time to make sure we continue to sample the equilibrium distribution of initial configs
			echo " " >> temp_submit.pbs
			echo 'cd $PBS_O_WORKDIR' >> temp_submit.pbs
			echo "grompp -f $TIMEMDP -p $TOP -c INIT/$BASE.gro -t INIT/$BASE.cpt -o INIT/$BASE.1 -maxwarn 1" >> temp_submit.pbs
			echo "cd INIT" >> temp_submit.pbs
			echo "mdrun -nt 1 -v -deffnm $BASE.1 >& qsub_mdrun.log" >> temp_submit.pbs


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
