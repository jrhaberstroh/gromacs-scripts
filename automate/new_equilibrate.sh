#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

Requires full path for input files; use ~/ or root.

OPTIONS:
   -h      Show this message
   -n 	   Number of cores to use (default = no -nt option)
   -c (*)  Location of .gro (or .pdb) file to use for the configuration
   -p (*)  Location of .top file to use for parameters
   -E (*)  Location of .mdp file to run for energy minimization
   -T (*)  Location of .mdp file to run for equilibration
   -P (*)  Location of .mdp file to run at equilibrium; it is run once between folders, so this file sets the separation time between cores
   -o      Output base directory (all data is put in subfolders) (default = pwd)
   -A      Output directory will be absolute
   -w	   Value for maxwarn (default = 0)
   -v      Verbose (default = false)
EOF
}



CORES=
GRO=
TOP=
EMMDP=
VTMDP=
PTMDP=
OUT=
ABS=
WARN=
VERBOSE=
while getopts “h:n:c:p:E:T:P:o:A:w:v” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         n)
             CORES=$OPTARG
             ;;
         c)
             GRO=$OPTARG
             ;;
       	 p)
             TOP=$OPTARG
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
	 w)
	     WARN=$OPTARG
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

if [[ -z $EMMDP ]] || [[ -z $VTMDP ]] || [[ -z $PTMDP ]] || [[ -z $TOP ]] || [[ -z $GRO ]]
then
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

if ! [[ -z $CORES ]]
then
	CORES="-nt $CORES"
fi

if ! [[ -z $WARN ]]
then
	WARN="-maxwarn $WARN"
fi

echo "OUT: $OUT"
cd $OUT
mkdir 1ENERGYMIN/
cd $OUT/1ENERGYMIN/
grompp -f $EMMDP -c $GRO -p $TOP -o 1ENERGYMIN $WARN
mdrun $CORES -v -deffnm 1ENERGYMIN
EMGRO="$OUT/1ENERGYMIN/1ENERGYMIN.gro"

cd $OUT
mkdir 2TEMPEQ/
cd $OUT/2TEMPEQ/
grompp -f $VTMDP -c $EMGRO -p $TOP -o 2TEMPEQ $WARN
mdrun $CORES -v -deffnm 2TEMPEQ
VTGRO="$OUT/2TEMPEQ/2TEMPEQ.gro"
VTCPT="$OUT/2TEMPEQ/2TEMPEQ.cpt"

cd $OUT
mkdir 3PRESEQ/
cd $OUT/3PRESEQ/
grompp -f $PTMDP -c $VTGRO -t $VTCPT -p $TOP -o 3PRESEQ $WARN
mdrun $CORES -v -deffnm 3PRESEQ
PTGRO="$OUT/3PRESEQ/3PRESEQ.gro"
PTCPT="$OUT/3PRESEQ/3PRESEQ.cpt"

echo $PTGRO
echo $PTCPT
