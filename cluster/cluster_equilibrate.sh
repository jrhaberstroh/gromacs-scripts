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
   -2 [+]  Running on Catamount@LBL. 4 cores per node, MPI and multi-tenancy.
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
while getopts “h:N:c:p:t:E:T:P:W:w:12q:n:v” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
	 N)
             NAME=$OPTARG
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
	 W)
	     WARN=$OPTARG
	     ;;
	 w)
	     WALL=$OPTARG
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
	 n)
	     P_THREAD=$OPTARG
	     ;;
         ?)
             echo "You passed a stupid argument: $OPTARG"
             usage
             exit
             ;;
     esac
done

if [[ -z $NAME ]] || [[ -z $TOP ]] || [[ -z $GRO ]]; then
    	echo "ERROR: Missing either name, top, or gro"
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

	GROMPP="grompp_sp"
	MDRUN_SMALL="aprun -n 24 mdrun_mpi_sp" # Energy minimization often crashes on too many cores; script may need to be upgraded for situations where fewer than 24 cores are needed.
	MDRUN="aprun -n $P_THREAD mdrun_mpi_sp"

	# GENERATE THE SCRIPT
	echo "#PBS -N $NAME-gmx" > $NAME.pbs
	echo "#PBS -l mppwidth=$P_THREAD" >> $NAME.pbs
	echo "#PBS -l walltime=$WALL" >> $NAME.pbs
	echo "#PBS -j oe" >> $NAME.pbs    	# Join stdout and error
	echo "#PBS -q $QUEUE" >> $NAME.pbs
	echo "#PBS -V" >> $NAME.pbs

	echo "module load gromacs/4.6.1-sp" >> $NAME.pbs
	echo "CRAY_ROOTFS=DSL" >> $NAME.pbs 	# From tech support, to get grompp_sp to run.

	echo 'if [[ -e $PBS_O_WORKDIR'"/$NAME ]]; then" >> $NAME.pbs
	echo "	rm -r "'$PBS_O_WORKDIR'"/$NAME/*" >> $NAME.pbs
	echo "else" >> $NAME.pbs
	echo "	mkdir "'$PBS_O_WORKDIR'"/$NAME" >> $NAME.pbs
	echo "fi" >> $NAME.pbs
	echo " " >> $NAME.pbs

	if ! [[ -z $EMMDP ]]; then
		echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
		echo "mkdir $NAME/1ENERGYMIN/" >> $NAME.pbs
		echo "$GROMPP -f $EMMDP -c $GRO -p $TOP -o $NAME/1ENERGYMIN/1ENERGYMIN $WARN" >> $NAME.pbs
		echo "cd $NAME/1ENERGYMIN/" >> $NAME.pbs
		echo "$MDRUN_SMALL -v -deffnm 1ENERGYMIN" >> $NAME.pbs
		echo "EMGRO='$NAME/1ENERGYMIN/1ENERGYMIN.gro'" >> $NAME.pbs
		echo " " >> $NAME.pbs
	else
		echo "EMGRO=$GRO"
	fi

	if ! [[ -z $VTMDP ]]; then
		echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
		echo "mkdir $NAME/2TEMPEQ/" >> $NAME.pbs
		echo "$GROMPP -f $VTMDP -c "'$EMGRO'" -p $TOP -o $NAME/2TEMPEQ/2TEMPEQ $WARN" >> $NAME.pbs
		echo "cd $NAME/2TEMPEQ/" >> $NAME.pbs
		echo "$MDRUN -v -deffnm 2TEMPEQ" >> $NAME.pbs
		echo "VTGRO='$NAME/2TEMPEQ/2TEMPEQ.gro'" >> $NAME.pbs
		echo "VTCPT='$NAME/2TEMPEQ/2TEMPEQ.cpt'" >> $NAME.pbs
		echo " " >> $NAME.pbs
	else
		echo "VTGRO=$GRO"
		echo "VTCPT=$CPTOPT"
	fi
	
	if ! [[ -z $PTMDP ]]; then	
		echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
		echo "mkdir $NAME/3PRESEQ/" >> $NAME.pbs
		echo "$GROMPP -f $PTMDP -c "'$VTGRO'" -t "'$VTCPT'" -p $TOP -o $NAME/3PRESEQ/3PRESEQ $WARN" >> $NAME.pbs
		echo "cd $NAME/3PRESEQ/" >> $NAME.pbs
		echo "$MDRUN -v -deffnm 3PRESEQ" >> $NAME.pbs
	fi
	#echo "PTGRO='$NAME/3PRESEQ/3PRESEQ.gro'" >> $NAME.pbs
	#echo "PTCPT='$NAME/3PRESEQ/3PRESEQ.cpt'" >> $NAME.pbs
fi


if [ $CLUSTER = "CATAMOUNT" ]; then
	if [[ -z $QUEUE ]]; then
		QUEUE="cm_normal" #Default queue for Hopper
	fi
	if [[ -z $WALL ]]; then
		WALL="05:00:00" #Default wall for Hopper
	fi

	# GENERATE THE SCRIPT
	echo "#PBS -N $NAME-gmx" > $NAME.pbs
	echo "#PBS -q $QUEUE" >> $NAME.pbs
	if [ $QUEUE = "cm_serial" ]; then
		echo "#PBS -l nodes=1:ppn=1:cm_serial" >> $NAME.pbs
	else 
		echo "#PBS -l nodes=$(($P_THREAD / 4)):ppn=4:catamount" >> $NAME.pbs
	fi
	echo "#PBS -l walltime=$WALL" >> $NAME.pbs
	echo "#PBS -j oe" >> $NAME.pbs
	echo "#PBS -V" >> $NAME.pbs

	MPICALL_GROMP=
	MPICALL_MDRUN=
	MPI=
	if [ $QUEUE = "cm_serial" ]; then
		echo "cm_serial queue requested, setting number of cores to 1."
		echo "module load gromacs/4.6" >> $NAME.pbs
	elif [[ $P_THREAD -gt 4 ]]; then
		echo "module load gromacs/4.6-mpi" >> $NAME.pbs
		MPI='_mpi'
		MPICALL_GROMP='mpirun -n 1'
		MPICALL_MDRUN="mpirun -n $P_THREAD"
	else
		echo "module load gromacs/4.6" >> $NAME.pbs
	fi
	echo " " >> $NAME.pbs

	if ! [[ -z $EMMDP ]]; then
		echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
		echo "mkdir -p $NAME/1ENERGYMIN/" >> $NAME.pbs
		echo "$MPICALL_GROMP grompp$MPI -f $EMMDP -c $GRO -p $TOP -o $NAME/1ENERGYMIN/1ENERGYMIN $WARN" >> $NAME.pbs
		echo "cd $NAME/1ENERGYMIN/" >> $NAME.pbs
		echo "$MPICALL_MDRUN mdrun$MPI -v -deffnm 1ENERGYMIN" >> $NAME.pbs
		echo "EMGRO='$NAME/1ENERGYMIN/1ENERGYMIN.gro'" >> $NAME.pbs
		echo " " >> $NAME.pbs
	else
		echo "EMGRO=$GRO"
	fi

	if ! [[ -z $VTMDP ]]; then
		echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
		echo "mkdir -p $NAME/2TEMPEQ/" >> $NAME.pbs
		echo "$MPICALL_GROMP grompp$MPI -f $VTMDP -c "'$EMGRO'" -p $TOP -o $NAME/2TEMPEQ/2TEMPEQ $WARN" >> $NAME.pbs
		echo "cd $NAME/2TEMPEQ/" >> $NAME.pbs
		echo "$MPICALL_MDRUN mdrun$MPI -v -deffnm 2TEMPEQ" >> $NAME.pbs
		echo "VTGRO='$NAME/2TEMPEQ/2TEMPEQ.gro'" >> $NAME.pbs
		echo "VTCPT='$NAME/2TEMPEQ/2TEMPEQ.cpt'" >> $NAME.pbs
		echo " " >> $NAME.pbs
	else
		echo "VTGRO=$GRO"
		echo "VTCPT=$CPTOPT"
	fi
	
	if ! [[ -z $PTMDP ]]; then	
		echo 'cd $PBS_O_WORKDIR' >> $NAME.pbs
		echo "mkdir -p $NAME/3PRESEQ/" >> $NAME.pbs
		echo "$MPICALL_GROMP grompp$MPI -f $PTMDP -c "'$VTGRO'" -t "'$VTCPT'" -p $TOP -o $NAME/3PRESEQ/3PRESEQ $WARN" >> $NAME.pbs
		echo "cd $NAME/3PRESEQ/" >> $NAME.pbs
		echo "$MPICALL_MDRUN mdrun$MPI -v -deffnm 3PRESEQ" >> $NAME.pbs
	fi
fi
