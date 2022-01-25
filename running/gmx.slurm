#!/bin/bash
#SBATCH --partition=cn
#SBATCH --job-name=gmx
#SBATCH --time=00:10:00
#SBATCH --nodes           1   
#SBATCH --ntasks-per-node 128
#SBATCH --cpus-per-task   2   

module purge
module load gromacs/2021/2021.4-intel-nogpu-openmpi-gcc

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}


# standard run command for mdrun
mpirun gmx_mpi mdrun -ntomp ${SLURM_CPUS_PER_TASK} -v -s benchMEM.tpr


# command for consistent benchmarking performance
#mpirun gmx_mpi mdrun -ntomp ${SLURM_CPUS_PER_TASK} -v -s benchMEM.tpr -resethway -dlb yes -notunepme -noconfout