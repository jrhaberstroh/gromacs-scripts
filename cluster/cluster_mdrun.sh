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
   -1 (+)  Setup PBS for hopper@nersc. Hopper has nodes with 24 cores. Default queue is reg_1hour with walltime=01:00:00 on one core with Thread-MPI.
   -2 (+)  Setup PBS for catamount#lbl. Catamount has nodes with 16 cores. Default queue is thread-mpi on one cm_normal mode with walltime=05:00:00. Note: [-q cm_serial] will set [-P 1] automatically, and will override the -P setting.
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

if [[ -z $MDP ]] || [[ -z $GRO ]] || [[ -z $TOP ]] || [[ -z $CPT ]] || [[ -z $CLUSTER ]] || [[ -z $NAME ]]
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
	if [[ -z $P_THREAD ]]; then
		P_THREAD=24
	fi

	GROMACS_VERSION="gromacs/4.6.1-sp"
	GROMPP="grompp_sp"
	MDRUN="aprun -n $P_THREAD mdrun_mpi_sp -nt $P_THREAD"

	# GENERATE THE SCRIPT
	echo "#PBS -N $NAME-gmx-md" > $NAME.pbs
	echo "#PBS -l mppwidth=$P_THREAD" >> $NAME.pbs
	echo "#PBS -l walltime=$WALL" >> $NAME.pbs
	echo "#PBS -j oe" >> $NAME.pbs    # Join stdout and error
	echo "#PBS -q $QUEUE" >> $NAME.pbs
	echo "#PBS -V" >> $NAME.pbs

	echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
	echo "module load $GROMACS_VERSION" >> $NAME.pbs
	echo "CRAY_ROOTFS=DSL" >> $NAME.pbs 	# From tech support, to get grompp_sp to run.
	echo " " >> $NAME.pbs

	echo "if ! [[ -e $NAME ]]; then" >> $NAME.pbs
	echo "	mkdir $NAME" >> $NAME.pbs 
	echo "else" >> $NAME.pbs
	echo "	rm -r $NAME/*" >> $NAME.pbs
	echo "fi" >> $NAME.pbs
	echo "$GROMPP -f $MDP -p $TOP -c $GRO -t $CPT $WARN -o $NAME/$NAME.tpr" >> $NAME.pbs
	echo "cd $NAME" >> $NAME.pbs
	echo "$MDRUN -v -deffnm $NAME >& qsub_mdrun.log" >> $NAME.pbs
	
	# SUBMIT THE SCRIPT
	if [[ $READY ]]; then 
		qsub $NAME.pbs
	fi
fi

if [ $CLUSTER = "CATAMOUNT" ]; then
	if [[ -z $QUEUE ]]; then
		QUEUE="cm_normal" #Default queue for Hopper
	fi
	if [[ -z $P_THREAD ]]; then
		P_THREAD=16
	fi
	if [[ -z $WALL ]]; then
		WALL="05:00:00" #Default wall for Hopper
	fi

	# GENERATE THE SCRIPT
	echo "#PBS -N $NAME-gmx-md" > $NAME.pbs
	echo "#PBS -q $QUEUE" >> $NAME.pbs
	if [ $QUEUE = "cm_serial" ]; then
		echo "#PBS -l nodes=1:ppn=1:cm_serial" >> $NAME.pbs
	else 
		echo "#PBS -l nodes=$(($P_THREAD / 16)):ppn=16:catamount" >> $NAME.pbs
	fi
	echo "#PBS -l walltime=$WALL" >> $NAME.pbs
	echo "#PBS -j oe" >> $NAME.pbs
	echo "#PBS -V" >> $NAME.pbs
	
	GROMP=
	MDRUN=
	if [ $QUEUE = "cm_serial" ]; then
		echo "cm_serial queue requested, setting number of cores to 1."
		echo "module load gromacs/4.6" >> $NAME.pbs
		MDRUN="mdrun -nt 1"
		GROMP="grompp"
	elif [[ $P_THREAD -gt 16 ]]; then
		echo "module load gromacs/4.6-mpi" >> $NAME.pbs
		MDRUN="mpirun -n $P_THREAD mdrun_mpi"
		GROMP='mpirun -n 1 grompp_mpi'
	else
		echo "module load gromacs/4.6" >> $NAME.pbs
		MDRUN="mdrun -nt $P_THREAD"
		GROMP="grompp"
	fi
	echo " " >> $NAME.pbs

	echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
	echo " " >> $NAME.pbs

	echo "if ! [[ -e $NAME ]]; then" >> $NAME.pbs
	echo "	mkdir $NAME" >> $NAME.pbs 
	echo "fi" >> $NAME.pbs

	#NOTE: NOT COMPLETE YET!	
	echo "grompp -f $MDP -p $TOP -c $GRO -t $CPT -o $NAME/md_$NAME $WARN -po $NAME/$NAME.mdp" >> $NAME.pbs
	echo "cd $NAME" >> $NAME.pbs
	if [ $QUEUE = "cm_serial" ]; then
		echo "mdrun -nt 1 -v -deffnm md_$NAME >& qsub_mdrun.log" >> $NAME.pbs
	else 
		echo "mdrun -v -deffnm md_$NAME >& qsub_mdrun.log" >> $NAME.pbs
	fi

	# SUBMIT THE SCRIPT
	if [ $READY ]; then
		qsub $NAME.pbs
	fi
fi
