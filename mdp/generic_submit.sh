#!/bin/bash'
#PBS -N RunMD
#PBS -q debug
#PBS -l mppwidth=192
#PBS -l walltime=00:30:00

module load gromacs/4-6-1-sp

GROMPP=grompp_sp
MDRUN=aprun -n 192 mdrun_mpi_sp

DIR=/global/homes/j/jhabers/Jobs/2014-07-10-TMViscosity
MDPDIR=$DIR/mdp
CFGDIR=$DIR/1SOL

COORD=tmv-cp-sol.gro
TOP=TOP-tmv-cp-sol.top


EMDIR=$DIR/md_1em
NVTDIR=$DIR/md_2nvt
NPTDIR=$DIR/md_3npt
rm -r $EMDIR
rm -r $NVTDIR
rm -r $NPTDIR
mkdir $EMDIR
mkdir $NVTDIR
mkdir $NPTDIR


OLDGRO=$CFGDIR/$COORD
NEWDIR=$EMDIR
NEWNAME=em_1steep
$GROMPP -c $OLDGRO -p $CFGDIR/$TOP -o $NEWDIR/$NEWNAME -f $MDPDIR/$NEWNAME -po $NEWDIR/$NEWNAME
cd $NEWDIR
$MDRUN -v -deffnm $NEWNAME
#OLDGRO=$EMDIR/em_1steep
#NEWNAME=em_2cg
#grompp_sp -c $OLDGRO -p $CFGDIR/$TOP -o $NEWDIR/$NEWNAME -f $MDPDIR/$NEWNAME -po $NEWDIR/$NEWNAME
#cd $NEWDIR
#mdrun_sp -v -deffnm $NEWNAME
#cd $DIR

OLDGRO=$EMDIR/em_1steep
NEWDIR=$NVTDIR
NEWNAME=nvt
$GROMPP -c $OLDGRO -p $CFGDIR/$TOP -o $NEWDIR/$NEWNAME -f $MDPDIR/$NEWNAME -po $NEWDIR/$NEWNAME
cd $NEWDIR
$MDRUN -v -deffnm $NEWNAME
cd $DIR

OLDGRO=$NVTDIR/nvt
NEWDIR=$NPTDIR
NEWNAME=npt
$GROMPP -c $OLDGRO -p $CFGDIR/$TOP -o $NEWDIR/$NEWNAME -f $MDPDIR/$NEWNAME -po $NEWDIR/$NEWNAME
cd $NEWDIR
$MDRUN -v -deffnm $NEWNAME
cd $DIR
