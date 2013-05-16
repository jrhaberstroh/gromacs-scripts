#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

This script will first generate a job that spawns some number of directories spaced by a large spacer. It will then generate an array hold-job to follow up the first job, a job that runs individual trajectories off of many cores, one for each spawned trajectory.

Requires all with [*]
Requires exactly one of [+]

OPTIONS:
   -h      Show this message
   -o [*]  Output naming scheme; kept consistent between folders & jobs
   -T [*]  Location of long .mdp file to run at equilibrium; it is run once between folders.
   -t [*]  Location of short .mdp file to run at equilibrium; it is run once between trajectories in a given folder.
   -f [*]  Location of .mdp file to run as a trajectory; alternates running with -t.
   -c [*]  Location of .gro file to use as initial configuration
   -p [*]  Location of .top file to use for parameters
   -t [*]  Location of .cpt file to use for initial checkpoint
   -N      Number of folders to generate (default=100)
   -n      Number of trajectories to generate in each directory (default=100)
   -1 [+]  Setup PBS for hopper@nersc
   -2 [+]  Setup PBS for cmserial on catamount@lbl (NOTE: Does not support -P, all jobs are run on single core)
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
NTRAJ=100
NFOLD=100
VERBOSE=
CLUSTER=
READY=
P_THREAD=
WALL=
WARN=
while getopts “ho:T:t:f:c:p:t:N:n:12Rp:W:w:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         o)
             NAME=$OPTARG
             ;;
         T)
             FOLDMDP=$OPTARG
             ;;
         t)
             STEPMDP=$OPTARG
             ;;
	 f)
             TRAJMDP=$OPTARG
             ;;
         c)
             GRO=$OPTARG
             ;;
       	 p)
             TOP=$OPTARG
             ;;
       	 t)
             CPT=$OPTARG
             ;;
	 N)
	     NFOLD=$OPTARG
	     ;;
	 n)
	     NTRAJ=$OPTARG
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
	 p)
	     P_THREAD=$OPTARG
	     ;;
         W)
             WARN=$OPTARG
             ;;
         w)
             WALL=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

NAME=
FOLDMDP=
STEPMDP=
TRAJMDP=
GRO=
CPT=
TOP=
if [[ -z $NAME ]] || [[ -z $FOLDMDP ]] || [[ -z $STEPMDP ]] || [[ -z $TRAJMDP ]] || [[ -z $GRO ]] || [[ -z $CPT ]] || [[ -z $TOP ]] || [[ -z $CLUSTER ]]
then
     echo "BAD INPUT."
     usage
     exit 1
fi

if [ $CLUSTER = "HOPPER" ]; then
	echo "Not yet built for Hopper"
fi

if [ $CLUSTER = "CATAMOUNT" ]; then
	if [ $P_THREAD -gt 1 ]; then
		echo "ERROR: Catamount cluster does not have allow for threading in multi-tenancy serial mode, do not use -P option."
	else
		GROMACS_VERSION='gromacs/4.6'
		#---------------------------------------
		# Setup the folders
		#---------------------------------------
		echo "#PBS -N $NAME-gmx-tprep" > $NAME-tprep.pbs
		echo "#PBS -q cm_normal" >> $NAME-tprep.pbs
		echo "#PBS -l nodes=4:ppn=4:catamount" >> $NAME-tprep.pbs
		echo "#PBS -j oe" >> $NAME-tprep.pbs
		echo "#PBS -V" >> $NAME-tprep.pbs
		echo " " >> $NAME-tprep.pbs
		
		#mdrun $CORES times. Make a new directory for each.
		echo "PREVGRO=" >> $NAME-tprep.pbs
		echo "PREVCPT=" >> $NAME-tprep.pbs
		
		echo "module load $GROMACS_VERSION" >> $NAME-tprep.pbs
		echo 'cd $PBS_O_WORKDIR' >> $NAME-tprep.pbs
		echo "mkdir $NAME-tprep" >> $NAME-tprep.pbs
		echo "cd $NAME-tprep" >> $NAME-tprep.pbs
		
		echo " " >> $NAME-tprep.pbs
		echo "for CTR in $(eval echo {1..$NFOLD})" >> $NAME-tprep.pbs
		echo "do" >> $NAME-tprep.pbs
		echo "	mkdir $NAME"'$CTR' >> $NAME-tprep.pbs
		echo "	cd $NAME"'$CTR' >> $NAME-tprep.pbs
		echo "	mkdir INIT" >> $NAME-tprep.pbs
		echo "	mkdir TRAJ" >> $NAME-tprep.pbs
		echo "	cd INIT" >> $NAME-tprep.pbs
		echo '	if [[ -z $PREVGRO ]]' >> $NAME-tprep.pbs
		echo "		then grompp -f $FOLDMDP -p $TOP -c $GRO -t $CPT -o "'init$CTR.tpr' >> $NAME-tprep.pbs
		echo "	else" >> $NAME-tprep.pbs
		echo "		grompp -f $FOLDMDP -p $TOP "'-c $PREVGRO -t $PREVCPT -o init$CTR.tpr' >> $NAME-tprep.pbs
		echo "	fi" >> $NAME-tprep.pbs
		echo "done" >> $NAME-tprep.pbs
		
		#Make a copy when done
		echo " " >> $NAME-tprep.pbs
		echo 'cd $PBS_O_WORKDIR' >> $NAME-tprep.pbs
		echo "cp -r $NAME-tprep $NAME-traj" >> $NAME-tprep.pbs


		JOBID=
		if [[ $READY ]]; then
			echo 'JOBID=`qsub $NAME-tprep.pbs`; fi'
			JOBID='fake'

		
		#---------------------------------------
		# Run the trajectories, array style
		#---------------------------------------
		echo "#PBS -N $NAME-gmx-traj" > $NAME-traj.pbs
		echo "#PBS -q cm_serial" >> $NAME-traj.pbs
		echo "#PBS -l nodes=1:ppn=1:cmserial" >> $NAME-traj.pbs
		#echo "#PBS -l walltime=01:00:00" >> $NAME-traj.pbs
		echo "#PBS -j oe" >> $NAME-traj.pbs

		echo 'cd $PBS_O_WORKDIR' >> $NAME-traj.pbs
		echo "cd $NAME-traj/$NAME"'$PBS_ARRAYID' >> $NAME-traj.pbs
		echo 'FULL=$(ls INIT | grep "\.cpt$" | head -n 1)' >> $NAME-traj.pbs
		echo 'BASE=${FULL//.cpt/}' >> $NAME-traj.pbs
	
		echo "module load $GROMACS_VERSION" >> $NAME-traj.pbs
		echo "export GMX_MAXBACKUP=-1" >> $NAME-traj.pbs
		echo " " >> $NAME-traj.pbs

		# Run the mini-spacer for an arbitrary time to make sure we continue to sample the equilibrium distribution of initial configs
		echo " " >> $NAME-traj.pbs
		echo 'cd $PBS_O_WORKDIR' >> $NAME-traj.pbs
		echo "grompp -f $TIMEMDP -p $TOP -c INIT/$BASE.gro -t INIT/$BASE.cpt -o INIT/$BASE.1 -maxwarn 1" >> $NAME-traj.pbs
		echo "cd INIT" >> $NAME-traj.pbs
		echo "mdrun -nt 1 -v -deffnm $BASE.1 >& qsub_mdrun.log" >> $NAME-traj.pbs


		echo "for (( num=1 ; num <= $NTRAJ ; num++)) ; do" >> $NAME-traj.pbs
		# Run the trajectory for an arbitrary time
		echo '	cd $PBS_O_WORKDIR' >> $NAME-traj.pbs
		echo "	grompp -f $MDP -p $TOP -c INIT/$BASE."'$num'".gro -t INIT/$BASE."'$num'".cpt -o TRAJ/traj"'$num'" -maxwarn 1" >> $NAME-traj.pbs
		echo "	cd TRAJ" >> $NAME-traj.pbs
		echo "	mdrun -nt 1 -v -deffnm traj"'$num'" >& qsub_mdrun.log" >> $NAME-traj.pbs

		# Run the mini-spacer for an arbitrary time to make sure we continue to sample the equilibrium distribution of initial configs
		echo " " >> $NAME-traj.pbs
		echo '	cd $PBS_O_WORKDIR' >> $NAME-traj.pbs
		echo "	grompp -f $TIMEMDP -p $TOP -c INIT/$BASE."'$num'".gro -t INIT/$BASE."'$num'".cpt -o INIT/$BASE."'$(($num+1))'" -maxwarn 1" >> $NAME-traj.pbs
		echo "	cd INIT" >> $NAME-traj.pbs
		echo "	mdrun -nt 1 -v -deffnm $BASE."'$(($num+1))'" >& qsub_mdrun.log" >> $NAME-traj.pbs
		echo "done" >> $NAME-traj.pbs
	# SUBMIT THE SCRIPT
		
		if [ $READY ]; then
			echo "qsub $NAME-traj.pbs -t 1-$NFOLD -W depend=afterok:$JOBID; fi" 
	fi
fi
