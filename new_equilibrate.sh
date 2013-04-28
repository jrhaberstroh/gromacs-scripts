#!/bin/bash

cd PRESSURE_EQ/
rm -f *
cd ../MIN/
rm -f *
cd ../EQMDRUN/
rm -f *
cd ../NEQMDRUN/
rm -f *
cd ..
rm smy_solvated.gro 
genbox -cp smy.pdb -cs tip4p.gro -o smy_solv.gro

cd MIN/
grompp -f ../scripts/zzenergy_min.mdp -c ../smy_solv.gro -p ../smytopol.top -o min
mdrun -nt 1 -v -deffnm min
cd ../PRESSURE_EQ/
grompp -f ../scripts/zzpressure_eq.mdp -c ../MIN/min.gro -p ../smytopol.top -o pressure_eq
mdrun -nt 1 -v -deffnm pressure_eq
cd ../EQMDRUN/
grompp -c ../PRESSURE_EQ/pressure_eq.gro -t ../PRESSURE_EQ/pressure_eq.cpt -f ../scripts/zzpressure_cont.mdp -p ../smytopol.top -o eqmdrun -maxwarn 1
mdrun -nt 1 -v -deffnm eqmdrun
cd ../NEQMDRUN/
grompp -c ../PRESSURE_EQ/pressure_eq.gro -t ../PRESSURE_EQ/pressure_eq.cpt -f ../scripts/zzneq_cont.mdp -p ../smytopol.top -o neqmdrun -maxwarn 1
mdrun -nt 1 -v -deffnm neqmdrun
