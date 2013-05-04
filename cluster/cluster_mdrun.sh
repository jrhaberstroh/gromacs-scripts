#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

This script will generate the .pbs file to submit on either Catamount or Hopper for running a single grompp + mdrun.
When passed -R, it will also run qsub on the generated .pbs file.

NOTE: Expects a -t argument, so this script is not well suited for doing an initial equilibration.
NOTE: -f, -p, -c, and -t files can be given as relative or absolute directories; grompp is called from pwd with the exact args.

OPTIONS:
   -h      Show this message (huh...)
   -N      Output naming scheme
   -f (*)  Location of .mdp file to run
   -p (*)  Location of .top file for ff parameters
   -c [*]  Location of .gro file for geometry of the system
   -t [*]  Location of .cpt file for continuation from equilibration
   -P      Number of cores per to run on, default is one full node on whichever selected cluster.
   -v      Verbose (default = false)
   -1 (+)  Setup PBS for hopper@nersc. Hopper has nodes with 24 cores. Default queue is reg_1hour with walltime=01:00:00.
   -2 (+)  Setup PBS for cmserial on catamount@lbl (NOTE: Does not support -P, all jobs are run on single core)
   -q      Manual override for queue to submit to.
   -w      Walltime override
   -W      Max number of allowed warnings for grompp (Default = 0)
   -R      READY TO SUBMIT; pass this argument to run qsub immediately.
EOF
}

NAME=
MDP=
TOP=
GRO=
CPT=
P_THREAD=
VERBOSE=
CLUSTER=
QUEUE=
WALL=
WARN=
READY=
while getopts “hN:f:p:c:t:P:v:12q:w:W:R” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
	 N)
             NAME=$OPTARG
             ;;
	 f)
             MDP=$OPTARG
             ;;
       	 p)
             TOP=$OPTARG
             ;;
         c)
             GRO=$OPTARG
             ;;
	 t)
	     CPT=$OPTARG
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
	 q)
	     QUEUE=$OPTARG
 	     ;;
	 R)
	     READY=1
	     ;;
	 w)
	     WALL=$OPTARG
	     ;;
	 W)
	     WARN=$OPTARG
	     ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z $MDP ]] || [[ -z $GRO ]] || [[ -z $TOP ]] || [[ -z $CPT ]] || [[ -z $CLUSTER ]]
then
     usage
     exit 1
fi

if ! [[ -z $WARN ]]; then
	WARN="-maxwarn $WARN"
fi

if [ $CLUSTER = "HOPPER" ]; then
	if [[ -z $QUEUE ]]; then
		QUEUE="regular" #Default queue for Hopper
	fi
	if [[ -z $WALL ]]; then
		WALL="01:00:00" #Default wall for Hopper
	fi

	# GENERATE THE SCRIPT
	echo "#PBS -N gmx_$NAME" > $NAME.pbs
	echo "#PBS -l mppwidth=$P_THREAD" >> $NAME.pbs
	echo "#PBS -l walltime=$WALL" >> $NAME.pbs
	echo "#PBS -j oe" >> $NAME.pbs    # Join stdout and error
	echo "#PBS -q $QUEUE" >> $NAME.pbs
	echo "#PBS -V" >> $NAME.pbs

	echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
	echo "module load gromacs" >> $NAME.pbs
	echo " " >> $NAME.pbs

	echo "if ! [[ -e $NAME ]]; then" >> $NAME.pbs
	echo "\tmkdir $NAME" >> $NAME.pbs 
	echo "else" >> $NAME.pbs
	echo "\trm -r $NAME/*; fi" >> $NAME.pbs
	echo "aprun -n 1 grompp_mpi -f $MDP -p $TOP -c $GRO -t $CPT $WARN -o $NAME/$NAME.tpr" >> $NAME.pbs
	echo "cd $NAME" >> $NAME.pbs
	echo "aprun -n $P_THREAD mdrun_mpi -v -deffnm $NAME >& qsub_mdrun.log" >> $NAME.pbs
	
	# SUBMIT THE SCRIPT
	if [[ $READY ]]; then 
		qsub $NAME.pbs
	fi
fi

if [ $CLUSTER = "CATAMOUNT" ]; then
	if [ $P_THREAD -gt 1 ]; then
		echo "ERROR: Catamount cluster does not have allow for threading in multi-tenancy serial mode, do not use -P option."
	else
		cd $INITWD/$dir
		FULL=$(ls INIT | grep "\.cpt$" | head -n 1)
		echo "FULL: " $FULL
		BASE=${FULL//.cpt/}
		echo "BASE: " $BASE
	
		# GENERATE THE SCRIPT
		echo "#PBS -N gmx_traj_$BASE" > $NAME.pbs
		echo "#PBS -q cm_serial" >> $NAME.pbs
		echo "#PBS -l nodes=1:ppn=1:cmserial" >> $NAME.pbs
		#echo "#PBS -l walltime=01:00:00" >> $NAME.pbs
		echo "#PBS -j oe" >> $NAME.pbs
		
		echo "cd $INITWD/$dir" >> $NAME.pbs
		echo "module load gromacs" >> $NAME.pbs
		echo " " >> $NAME.pbs

		#NOTE: NOT COMPLETE YET!	
		#echo "grompp -f $MDP -p $TOP -c INIT/$BASE.gro -t INIT/$BASE.cpt -o TRAJ/traj -maxwarn 1" >> $NAME.pbs
		#echo "cd $INITWD/$dir/TRAJ" >> $NAME.pbs
		#echo "mdrun -nt 1 -v -deffnm traj >& qsub_mdrun.log" >> $NAME.pbs

		# SUBMIT THE SCRIPT
		if [ $READY ]; then
			qsub $NAME.pbs
		fi
	fi
fi
