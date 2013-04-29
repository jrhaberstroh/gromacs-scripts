#!/bin/bash

cd EQMDRUN/
grompp -f ../scripts/eqstep_md.mdp -c eqmdrun.gro -t eqmdrun.cpt -p ../smytopol.top -o eqmdrun
mdrun -nt 1 -v -deffnm eqmdrun
cd ../NEQMDRUN/
grompp -f ../scripts/neq_md.mdp -c ../EQMDRUN/eqmdrun.gro -t ../EQMDRUN/eqmdrun.cpt -p ../smytopol.top -o neqmdrun -maxwarn 1
mdrun -nt 1 -v -deffnm neqmdrun 
cd ..
