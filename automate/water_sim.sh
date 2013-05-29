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
   -w      Width of the simulation box, in nm (default = 2 nm)
   -t [*]  Thickness of the box, in nm
EOF
}

WIDTH=2
THICK=
while getopts “ht:w:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         w)
	     WIDTH=
             ;;
         t)
	     THICK=
             ;;
         ?)
             echo "You passed a stupid argument: $OPTARG"
             usage
             exit
             ;;
     esac
done

if [[ -z $THICK ]]; then
	echo "***ERROR: Missing or malformed -t argument (required)"
	usage
	exit 1
fi
