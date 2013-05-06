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
	echo "#PBS -N $NAME-gmx-md" > $NAME.pbs
	echo "#PBS -l mppwidth=$P_THREAD" >> $NAME.pbs
	echo "#PBS -l walltime=$WALL" >> $NAME.pbs
	echo "#PBS -j oe" >> $NAME.pbs    # Join stdout and error
	echo "#PBS -q $QUEUE" >> $NAME.pbs
	echo "#PBS -V" >> $NAME.pbs

	echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
	echo "module load gromacs" >> $NAME.pbs
	echo " " >> $NAME.pbs

	echo "if ! [[ -e $NAME ]]; then" >> $NAME.pbs
	echo "	mkdir $NAME" >> $NAME.pbs 
	echo "else" >> $NAME.pbs
	echo "	rm -r $NAME/*" >> $NAME.pbs
	echo "fi" >> $NAME.pbs
	echo "aprun -n 1 grompp_mpi -f $MDP -p $TOP -c $GRO -t $CPT $WARN -o $NAME/$NAME.tpr" >> $NAME.pbs
	echo "cd $NAME" >> $NAME.pbs
	echo "aprun -n $P_THREAD mdrun_mpi -v -deffnm $NAME >& qsub_mdrun.log" >> $NAME.pbs
	
	# SUBMIT THE SCRIPT
	if [[ $READY ]]; then 
		qsub $NAME.pbs
	fi
fi

if [ $CLUSTER = "CATAMOUNT" ]; then
	if [[ -z $QUEUE ]]; then
		QUEUE="cm_normal" #Default queue for Hopper
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
		echo "#PBS -l nodes=4:ppn=4:catamount" >> $NAME.pbs
	fi
	echo "#PBS -l walltime=$WALL" >> $NAME.pbs
	echo "#PBS -j oe" >> $NAME.pbs
	echo "#PBS -V" >> $NAME.pbs
	
	echo "module load gromacs" >> $NAME.pbs
	echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
	echo " " >> $NAME.pbs

	echo "if ! [[ -e $NAME ]]; then" >> $NAME.pbs
	echo "	mkdir $NAME" >> $NAME.pbs 
	echo "fi" >> $NAME.pbs

	#NOTE: NOT COMPLETE YET!	
	echo "grompp -f $MDP -p $TOP -c $GRO -t $CPT -o $NAME/md_$NAME $WARN" >> $NAME.pbs
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
