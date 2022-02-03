#!/bin/bash

# download the source code
wget https://ftp.gromacs.org/gromacs/gromacs-2021.4.tar.gz

# extract
tar xvf gromacs-2021.4.tar.gz

# move into the source code directory
cd gromacs-2021.4

# make the build directory
mkdir build
cd build

# load the required modules
module purge
module load cmake
module load fftw/3/3.3.10-gcc-openmpi
module load openmpi/4/gcc/latest
module load openblas/latest-gcc

# cmake configuration
cmake .. -DCMAKE_INSTALL_PREFIX=$(pwd)/.. -DGMX_MPI=ON -DGMX_OPENMP=ON \
    -DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpicxx \
    -DREGRESSIONTEST_DOWNLOAD=ON \
    -DGMX_FFT_LIBRARY=fftw3 -DFFTWF_LIBRARY=/opt/software/fftw/3/3.3.10-gcc-openmpi/lib/libfftw3f.so -DFFTWF_INCLUDE_DIR=/opt/software/fftw/3/3.3.10-gcc-openmpi/include

# build
make -j8

# Optional: test the build, uncomment the line below to build and run the regression tests
#make -j8 check

# install
make install
