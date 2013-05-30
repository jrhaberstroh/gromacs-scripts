#!/bin/bash

usage()
{
cat << EOF
===================================
water_sim.sh
===================================

A shell script to automate simulation of slab geometry water in GROMACS.

usage: $0 

OPTIONS:
   -h      Show this message
   -N      Naming scheme, [default = water_t=\$THICK]
   -w      Width of the simulation box, in nm (default = 2 nm)
   -t [*]  Thickness of the box, in nm
EOF
}

WIDTH=5.0
THICK=
NAME=
while getopts “hN:t:w:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         N)
	     NAME=$OPTARG
             ;;
         w)
	     WIDTH=$OPTARG
             ;;
         t)
	     THICK=$OPTARG
	     NAME="water-t$THICK"
             ;;
         ?)
             echo "You passed a stupid argument: $OPTARG"
             usage
             exit
             ;;
     esac
done


if [[ -z $THICK ]]; then
	echo "***ERROR: Missing or malformed -t thickness argument (required)"
	usage
	exit 1
fi


if [[ -z $NAME ]]; then
	echo "***ERROR: Missing or malformed -N name argument (required)"
	usage
	exit 1
fi


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# Generate the .gro and .top files
cp $SCRIPT_DIR/water_sim/water_sim.top $NAME.top
genbox -cs tip4p.gro -box $WIDTH $WIDTH $THICK -o $NAME.gro -p $NAME.top
rm \#$NAME.top.1\#

EQDIR=eq$NAME

# Equilibrate
if ! [ -e $EQDIR ]; then
	mkdir $EQDIR
fi
grompp -f $SCRIPT_DIR/water_sim/em.mdp -o $EQDIR/em -po $EQDIR/em.mdp -c $NAME.gro -p $NAME.top >& $EQDIR/em_grompp.err
cd $EQDIR
mdrun -v -deffnm em >& em.err
cd -

grompp -f $SCRIPT_DIR/water_sim/nvt.mdp -o $EQDIR/nvt -po $EQDIR/nvt.mdp -c $EQDIR/em.gro -p $NAME.top >& $EQDIR/nvt_grompp.err
cd $EQDIR
mdrun -v -deffnm nvt >& nvt.err
cd -

grompp -f $SCRIPT_DIR/water_sim/npt.mdp -o $EQDIR/npt -po $EQDIR/npt.mdp -c $EQDIR/em.gro -p $NAME.top -t $EQDIR/nvt.cpt >& $EQDIR/npt_grompp.err
cd $EQDIR
mdrun -v -deffnm npt >& npt.err
cd -

#Important to check the slab thickness in post-analysisS
