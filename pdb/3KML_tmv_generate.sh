#!/bin/bash  
GRO="TMV_0pdb.gro"
CTR="TMV_1ctr.gro"
SOL="TMV_2sol.gro"
TOP="TMV.top"
# -angles 90 90 120 are the (bc, ac, ab) == (yz, xz, xy) angles, and thus a hexagonal-prism box
pdb2gmx -f 3KML.pdb -o $GRO -p $TOP -ff amber03 -water spce -merge all
editconf -f $GRO -o $CTR -princ -c -bt tric -angles 90 90 120 -d 1.2
genbox  -cp $CTR -o $SOL -cs spc216.gro -p $TOP
rm -f \#*\#
echo "Make sure to use comm-mode = Angular in your .mdp!"
