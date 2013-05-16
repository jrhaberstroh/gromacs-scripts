#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

Script for doing an equilibration run of a .gro & .top file.

The .pbs file for submission is created in the current working directory.
Input directories are fed directly into gromacs commands from the current working directory, so both absolute and relative are accepted.
[*] are required
[$] are fundamental options, and should be selected from to allow the script to do anything.
[+] are require you to select exactly one of

OPTIONS:
   -h      Show this message
   -N [*]  Output naming scheme
   -c (*)  Location of .gro (or .pdb) file to use for the configuration
   -p (*)  Location of .top file to use for parameters
   -t      Location of .cpt file if only a NPT run is needed.
   -E [$]  Location of .mdp file to run for energy minimization
   -T [$]  Location of .mdp file to run for equilibration
   -P [$]  Location of .mdp file to run at equilibrium; it is run once between folders, so this file sets the separation time between cores
   -W	   Value for maxwarn (default = 0)
   -w      Walltime override
   -1 [+]  Running on Hopper@NERSC. 24 cores per node, single tenancy, MPI.
   -2 [+]  Running on Catamount@LBL. 4 cores per node, multi-thread and multi-tenancy. MPI will activate if more than 4 cores are requested.
   -q      Manual override for queue to submit to.
   -n 	   Number of cores to use (default = no -nt option)
   -v      Verbose (default = false)
EOF
}



NAME=
GRO=
TOP=
CPTOPT=
EMMDP=
VTMDP=
PTMDP=
OUT=
ABS=
WALL=
WARN=
P_THREAD=
QUEUE=
VERBOSE=
CLUSTER=
while getopts “h:N:n:c:p:E:T:P:o:A:W:w:q:vt:12” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
	 N)
             NAME=$OPTARG
             ;;
         n)
             P_THREAD=$OPTARG
             ;;
         c)
             GRO=$OPTARG
             ;;
       	 p)
             TOP=$OPTARG
             ;;
       	 t)
             CPTOPT=$OPTARG
             ;;
         E)
             EMMDP=$OPTARG
             ;;
       	 T)
             VTMDP=$OPTARG
             ;;
	 P)
	     PTMDP=$OPTARG
	     ;;
	 o)
	     OUT=$OPTARG
	     ;;
	 A)
	     ABS=1
	     ;;
	 W)
	     WARN=$OPTARG
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
	 w)
	     WALL=$OPTARG
	     ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z $NAME ]] || [[ -z $TOP ]] || [[ -z $GRO ]]
then
     usage
     exit 1
fi

if [ $CLUSTER = "HOPPER" ] && [[ -z $P_THREAD ]]; then
	echo " "
     	echo "ERROR: Hopper requires the user to input the number of processors to use. Supply the -n command."
	usage
	exit 1
fi

GRO=$GRO
TOP=$TOP
EMMDP=$EMMDP
VTMDP=$VTMDP
PTMDP=$PTMDP
if [[ -z $ABS ]]
then
	OUT=$(pwd)/$OUT
fi

if [[ -z $OUT ]] || ! [[ -e $OUT ]] 
then
	OUT=$(pwd)
fi

if ! [[ -z $WARN ]]
then
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
	echo "#PBS -N $NAME-gmx-eq" > eq_$NAME.pbs
	echo "#PBS -l mppwidth=$P_THREAD" >> eq_$NAME.pbs
	echo "#PBS -l walltime=$WALL" >> eq_$NAME.pbs
	echo "#PBS -j oe" >> eq_$NAME.pbs    # Join stdout and error
	echo "#PBS -q $QUEUE" >> eq_$NAME.pbs
	echo "#PBS -V" >> eq_$NAME.pbs

	echo "module load gromacs" >> eq_$NAME.pbs
	echo 'if [[ -e $PBS_O_WORKDIR'"/$NAME ]]; then" >> eq_$NAME.pbs
	echo "	rm -r "'$PBS_O_WORKDIR'"/$NAME/*" >> eq_$NAME.pbs
	echo "else" >> eq_$NAME.pbs
	echo "	mkdir "'$PBS_O_WORKDIR'"/$NAME" >> eq_$NAME.pbs
	echo "fi" >> eq_$NAME.pbs
	echo " " >> eq_$NAME.pbs

	if ! [[ -z $EMMDP ]]; then
		echo 'cd $PBS_O_WORKDIR' >> eq_$NAME.pbs
		echo "mkdir $NAME/1ENERGYMIN/" >> eq_$NAME.pbs
		echo "aprun -n 1 grompp_mpi -f $EMMDP -c $GRO -p $TOP -o $NAME/1ENERGYMIN/1ENERGYMIN $WARN" >> eq_$NAME.pbs
		echo "cd $NAME/1ENERGYMIN/" >> eq_$NAME.pbs
		echo "aprun -n $P_THREAD mdrun_mpi -v -deffnm 1ENERGYMIN" >> eq_$NAME.pbs
		echo "EMGRO='$NAME/1ENERGYMIN/1ENERGYMIN.gro'" >> eq_$NAME.pbs
		echo " " >> eq_$NAME.pbs
	else
		echo "EMGRO=$GRO"
	fi

	if ! [[ -z $VTMDP ]]; then
		echo 'cd $PBS_O_WORKDIR' >> eq_$NAME.pbs
		echo "mkdir $NAME/2TEMPEQ/" >> eq_$NAME.pbs
		echo "aprun -n 1 grompp_mpi -f $VTMDP -c "'$EMGRO'" -p $TOP -o $NAME/2TEMPEQ/2TEMPEQ $WARN" >> eq_$NAME.pbs
		echo "cd $NAME/2TEMPEQ/" >> eq_$NAME.pbs
		echo "aprun -n $P_THREAD mdrun_mpi -v -deffnm 2TEMPEQ" >> eq_$NAME.pbs
		echo "VTGRO='$NAME/2TEMPEQ/2TEMPEQ.gro'" >> eq_$NAME.pbs
		echo "VTCPT='$NAME/2TEMPEQ/2TEMPEQ.cpt'" >> eq_$NAME.pbs
		echo " " >> eq_$NAME.pbs
	else
		echo "VTGRO=$GRO"
		echo "VTCPT=$CPTOPT"
	fi
	
	if ! [[ -z $PTMDP ]]; then	
		echo 'cd $PBS_O_WORKDIR' >> eq_$NAME.pbs
		echo "mkdir $NAME/3PRESEQ/" >> eq_$NAME.pbs
		echo "aprun -n 1 grompp_mpi -f $PTMDP -c "'$VTGRO'" -t "'$VTCPT'" -p $TOP -o $NAME/3PRESEQ/3PRESEQ $WARN" >> eq_$NAME.pbs
		echo "cd $NAME/3PRESEQ/" >> eq_$NAME.pbs
		echo "aprun -n $P_THREAD mdrun_mpi -v -deffnm 3PRESEQ" >> eq_$NAME.pbs
	fi
	#echo "PTGRO='$NAME/3PRESEQ/3PRESEQ.gro'" >> eq_$NAME.pbs
	#echo "PTCPT='$NAME/3PRESEQ/3PRESEQ.cpt'" >> eq_$NAME.pbs
fi


if [ $CLUSTER = "CATAMOUNT" ]; then
	if [[ -z $QUEUE ]]; then
		QUEUE="cm_normal" #Default queue for Hopper
	fi
	if [[ -z $WALL ]]; then
		WALL="05:00:00" #Default wall for Hopper
	fi

	# GENERATE THE SCRIPT
	echo "#PBS -N $NAME-gmx-eq" > eq_$NAME.pbs
	echo "#PBS -q $QUEUE" >> eq_$NAME.pbs
	if [ $QUEUE = "cm_serial" ]; then
		echo "#PBS -l nodes=1:ppn=1:cm_serial" >> eq_$NAME.pbs
	else 
		echo "#PBS -l nodes=$P_THREAD:ppn=$P_THREAD:catamount" >> eq_$NAME.pbs
	fi
	echo "#PBS -l walltime=$WALL" >> eq_$NAME.pbs
	echo "#PBS -j oe" >> eq_$NAME.pbs
	echo "#PBS -V" >> eq_$NAME.pbs

	MPICALL_GROMP=
	MPICALL_MDRUN=
	MPI=
	if [ $QUEUE = "cm_serial" ]; then
		echo "cm_serial queue requested, setting number of cores to 1."
		echo "module load gromacs/4.6" >> eq_$NAME.pbs
	elif [[ $P_THREAD -gt 4 ]]
		echo "module load gromacs/4.6-mpi" >> eq_$NAME.pbs
		MPI='_mpi'
		MPICALL_GROMP='aprun -n 1'
		MPICALL_MDRUN="aprun -n $P_THREAD"
	else
		echo "module load gromacs/4.6" >> eq_$NAME.pbs
	fi


	echo 'if [[ -e $PBS_O_WORKDIR'"/$NAME ]]; then" >> eq_$NAME.pbs
	echo "	rm -r "'$PBS_O_WORKDIR'"/$NAME/*" >> eq_$NAME.pbs
	echo "else" >> eq_$NAME.pbs
	echo "	mkdir "'$PBS_O_WORKDIR'"/$NAME" >> eq_$NAME.pbs
	echo "fi" >> eq_$NAME.pbs
	echo " " >> eq_$NAME.pbs

	if ! [[ -z $EMMDP ]]; then
		echo 'cd $PBS_O_WORKDIR' >> eq_$NAME.pbs
		echo "mkdir $NAME/1ENERGYMIN/" >> eq_$NAME.pbs
		echo "$MPICALL_GROMP grompp$MPI -f $EMMDP -c $GRO -p $TOP -o $NAME/1ENERGYMIN/1ENERGYMIN $WARN" >> eq_$NAME.pbs
		echo "cd $NAME/1ENERGYMIN/" >> eq_$NAME.pbs
		echo "$MPICALL_MDRUN mdrun$MPI -v -deffnm 1ENERGYMIN" >> eq_$NAME.pbs
		echo "EMGRO='$NAME/1ENERGYMIN/1ENERGYMIN.gro'" >> eq_$NAME.pbs
		echo " " >> eq_$NAME.pbs
	else
		echo "EMGRO=$GRO"
	fi

	if ! [[ -z $VTMDP ]]; then
		echo 'cd $PBS_O_WORKDIR' >> eq_$NAME.pbs
		echo "mkdir $NAME/2TEMPEQ/" >> eq_$NAME.pbs
		echo "$MPICALL_GROMP grompp$MPI -f $VTMDP -c "'$EMGRO'" -p $TOP -o $NAME/2TEMPEQ/2TEMPEQ $WARN" >> eq_$NAME.pbs
		echo "cd $NAME/2TEMPEQ/" >> eq_$NAME.pbs
		echo "$MPICALL_MDRUN mdrun$MPI -v -deffnm 2TEMPEQ" >> eq_$NAME.pbs
		echo "VTGRO='$NAME/2TEMPEQ/2TEMPEQ.gro'" >> eq_$NAME.pbs
		echo "VTCPT='$NAME/2TEMPEQ/2TEMPEQ.cpt'" >> eq_$NAME.pbs
		echo " " >> eq_$NAME.pbs
	else
		echo "VTGRO=$GRO"
		echo "VTCPT=$CPTOPT"
	fi
	
	if ! [[ -z $PTMDP ]]; then	
		echo 'cd $PBS_O_WORKDIR' >> eq_$NAME.pbs
		echo "mkdir $NAME/3PRESEQ/" >> eq_$NAME.pbs
		echo "$MPICALL_GROMP grompp$MPI -f $PTMDP -c "'$VTGRO'" -t "'$VTCPT'" -p $TOP -o $NAME/3PRESEQ/3PRESEQ $WARN" >> eq_$NAME.pbs
		echo "cd $NAME/3PRESEQ/" >> eq_$NAME.pbs
		echo "$MPICALL_MDRUN mdrun$MPI -v -deffnm 3PRESEQ" >> eq_$NAME.pbs
	fi
fi
