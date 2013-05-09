#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

This script generates a .pbs file, which is a job that generates a collection of directories, spaced by repeated calls to the -f argument. The main purpose of this is to generate decorrelated regions within which to harvest trajectories.

This job is inherently serial, though mdrun can be parallel distributed.
If MPI is wanted, qsub must be called:
>> qsub -l mppwidth=NUM_CORES
That argument must be passed with -P here as well.
NOTE: (*) options are mandatory and have no defaults.
NOTE: All files must be given as absolute locations because script will call cd before grompp.

OPTIONS:
   -h      Show this message
   -n (*)  Number of cores to prepare for, will also be the number of directories spawned
   -f (*)  Location of .mdp file to run at equilibrium; it is run once between folders, so this file sets the separation time between cores
   -c (*)  Location of .gro (or .pdb) file to use for the configuration
   -t (*)  Location of .cpt file (from equilibration, usually)
   -p (*)  Location of .top file to use for parameters
   -P      Run with mdrun_mpi; Specifies the number of cores available. default=0 for mdrun without MPI
   -N      Naming scheme, default is CORE
   -v      Verbose (default = false)
EOF
}



CORES=
MDP=
GRO=
CPT=
TOP=
PLL=0
NAME='CORE'
VERBOSE=
while getopts “h:n:f:c:t:p:P:N:v” OPTION
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
	 N)
	     NAME=$OPTARG
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


echo $CORES
echo $TIME

echo "#PBS -N $NAME-gmx-tprep" > $NAME-tprep.pbs
echo "#PBS -q cm_normal" >> $NAME-tprep.pbs
echo "#PBS -l nodes=4:ppn=4:catamount" >> $NAME-tprep.pbs
echo "#PBS -j oe" >> $NAME-tprep.pbs
echo "#PBS -V" >> $NAME-tprep.pbs

#mdrun $CORES times. Make a new directory for each.
echo "DIGITS=${#CORES}" >> $NAME-tprep.pbs
echo "PREVGRO=" >> $NAME-tprep.pbs
echo "PREVCPT=" >> $NAME-tprep.pbs

echo "module load gromacs" >> $NAME-tprep.pbs
echo 'cd $PBS_O_WORKDIR' >> $NAME-tprep.pbs
echo "mkdir $NAME-tprep" >> $NAME-tprep.pbs
echo "cd $NAME-tprep" >> $NAME-tprep.pbs

echo "for CTR in $(eval echo {1..$CORES})" >> $NAME-tprep.pbs
echo "do" >> $NAME-tprep.pbs
#Allows ls to order cores numerically by using leading zeros.
echo '	printf -v PRE "%$(echo $DIGITS)d" $CTR' >> $NAME-tprep.pbs #Stores into PRE the number $CTR with char* length $DIGITS
echo '	STR=${PRE// /'0'}' >> $NAME-tprep.pbs  			#Replaces the blanks with 0's 
echo "	mkdir $NAME"'$STR' >> $NAME-tprep.pbs
echo "	cd $NAME"'$STR' >> $NAME-tprep.pbs
echo "	mkdir INIT" >> $NAME-tprep.pbs
echo "	mkdir TRAJ" >> $NAME-tprep.pbs
echo "	cd INIT" >> $NAME-tprep.pbs
echo '	if [[ -z $PREVGRO ]]' >> $NAME-tprep.pbs
echo "		then grompp -f $MDP -p $TOP -c $GRO -t $CPT -o "'init$STR.tpr' >> $NAME-tprep.pbs
echo "	else" >> $NAME-tprep.pbs
echo "		grompp -f $MDP -p $TOP "'-c $PREVGRO -t $PREVCPT -o init$STR.tpr' >> $NAME-tprep.pbs
echo "	fi" >> $NAME-tprep.pbs
		
if [ $PLL -eq 0 ]; then
	echo '	mdrun -v -deffnm init$STR' >> $NAME-tprep.pbs
else	
	echo "	aprun -n $PLL mdrun_mpi "'-deffnm init$STR>& test.log' >> $NAME-tprep.pbs
fi
	
echo '	PREVCPT=$(pwd)/init$STR.cpt' >> $NAME-tprep.pbs
echo '	PREVGRO=$(pwd)/init$STR.gro' >> $NAME-tprep.pbs
echo "	cd ../.." >> $NAME-tprep.pbs
echo "done" >> $NAME-tprep.pbs
