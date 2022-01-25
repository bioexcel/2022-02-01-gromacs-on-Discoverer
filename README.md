# Discoverer GROMACS lesson

# Running GROMACS

## Loading the module

The first step to running GROMACS on Discover is to load one of the GROMACS modules. There are several available, you can view them with the ``module avail gromacs`` command

```bash
module avail gromacs
```

The out put will look similar to this:
>```
>------------------------------------------ /opt/software/modulefiles -------------------------
>gromacs/2021/2021.3-intel-nogpu-mpi           gromacs/2021/2021.4-oneapi-nogpu-mpi          
>gromacs/2021/2021.3-intel-nogpu-nompi         gromacs/2021/latest-intel-nogpu-mpi           
>gromacs/2021/2021.4-intel-nogpu-mpi           gromacs/2021/latest-intel-nogpu-nompi         
>gromacs/2021/2021.4-intel-nogpu-nompi         gromacs/2021/latest-intel-nogpu-openmpi-aocc  
>gromacs/2021/2021.4-intel-nogpu-openmpi-aocc  gromacs/2021/latest-intel-nogpu-openmpi-gcc   
>gromacs/2021/2021.4-intel-nogpu-openmpi-gcc   gromacs/2021/latest-oneapi-nogpu-mpi    
>```

There are currently two different release version 2021.3 and 2021.4. And multiple different builds. All should give good performance and the same results. We recommend the version that uses OpenMPI and gcc, this is the one called ``gromacs/2021/latest-intel-nogpu-openmpi-gcc``  

```bash
module load gromacs/2021/latest-intel-nogpu-openmpi-gcc
``` 

---
## The input .tpr file

The part of GROMACS that runs the molecular dynamics simulation is the ``mdrun`` program. It takes a binary input file (which was file extension ``.tpr``) which contains the starting molecular structure and the simulation parameters.

We will use a standard benchmark called ``benchMEM.trp`` which is available from https://www.mpinat.mpg.de/grubmueller/bench and has been used to report on GROMACS performance on different systems https://doi.org/10.1002/jcc.24030 .

This benchmark simulates a membrane channel protein embedded in a lipid bilayer surrounded by water and ions. With its size of ~80 000 atoms, it serves as a prototypical example for a large class of setups used to study all kinds of membrane-embedded proteins.

You will find this file in the ``running`` subdirectory of this repo.

It is a binary file so cannot be opened with a text editor, but the contents can be viewed using the ``gmx dump`` tool

```bash
gmx_mpi dump -s benchMEM.tpr
```
---

## Running a simulation on the compute nodes

The simulation is run using ``mdrun``. For this we will need to run it on the compute nodes using the Slurm batch system.

The script to do this is the file called ``gmx.slurm``:

```bash
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

mpirun gmx_mpi mdrun -ntomp ${SLURM_CPUS_PER_TASK} -v -s benchMEM.tpr

```

You can run this using the ``sbatch`` command

```bash
sbatch gmx.slurm
```
---

## Benchmarking

Before running a long MD simulation you will want to benchmark the system to find the optimal number of parallel processes to use. 

You do this by changing the number of nodes, tasks, and cpus-per-task.

Usually GROMACS works best with 1 MPI task per physical core. Discoverer has 128 physical cores per node, it also has SMT which means each physical core has two logical cores.

In the example script the ``#SBATCH`` directives are setup to use a full node with 128 MPI tasks and 2 OMP threads per task, which makes use of the SMT.

You should try running with less MPI tasks, for this you just need to change the ``#SBATCH --ntasks-per-node`` line

E.g. for 16 MPI tasks:
```
#SBATCH --nodes           1    
#SBATCH --ntasks-per-node 16
#SBATCH --cpus-per-task   2   
```

To run with more than 128 MPI tasks you will need to change the ``#SBATCH --nodes`` line

E.g. for 256 MPI tasks:
```
#SBATCH --nodes           2    
#SBATCH --ntasks-per-node 128
#SBATCH --cpus-per-task   2   
```

**NOTE** 
For consistent benchmarking results and optimal performance for this benchmark input we have found that you should add the flags ``-resethway -dlb yes -notunepme -noconfout`` to the ``mdrun`` command.


```bash
mpirun gmx_mpi mdrun -ntomp ${SLURM_CPUS_PER_TASK} -v -s benchMEM.tpr -resethway -dlb yes -notunepme -noconfout
```

- ``-resethway`` resets the performance timers halfway through the run, this removes the overhead of initializion and load balancing from the reported timings. 
- ``-dlb yes`` turns on dynamic load balancing which shifts particles between MPI ranks to optimize performance. This can interfere with the ``tunepme`` setting which will optimize various aspects of the PME and DD algorithms, shifting load between ranks.
- ``-notunepme`` turns off PME load balancing because it can interfere with the ``dlb yes`` setting. The PME settings can be tuned separately using ``gmx tune_pme``. 

- ``-noconfout`` does not create the output conformation as this is not needed for benchmarking.



The performance is reported at the bottom of the ``slurm-*.out`` and ``md.log`` files

>```bash
>tail md.log
>```

```bash
               Core t (s)   Wall t (s)        (%)
       Time:     1432.575        5.598    25589.8
                 (ns/day)    (hour/ns)
Performance:      154.366        0.155
```
---





## Things to investigate
- You should try running with the following number of MPI processes:
16, 32, 64, 128, 256, 512
- Plot the results as graph
- What happens if you try using 1024?
- Try turning off SMT, this is done by modifying the slurm script settings to:
    ```bash
    #!/bin/bash
    #SBATCH --partition=cn
    #SBATCH --job-name=gmx
    #SBATCH --time=00:10:00
    #SBATCH --hint=nomultithread
    #SBATCH --nodes           1    
    #SBATCH --ntasks-per-node 128
    #SBATCH --cpus-per-task   1   
    ```
- Try using the other GROMACS modules and comparing the performance:
    - aocc + OpenMPI: 
        ```
        module load gromacs/2021/2021.4-intel-nogpu-openmpi-aocc
        ```
    - aocc + MPICH:
        ```
        gromacs/2021/2021.4-intel-nogpu-mpi 
        ```
---




# Building GROMACS

We found that for most benchmarks the optimally performing version of GROMACS is obtained using GCC and OpenMPI. 

This guide contains the steps needed to build GROMACS on Discoverer explaining some of the process. Anything in a code block can be directly copied and pasted into the terminal.

## Step 1: Download

The first step is to download the GROMACS source code.


```bash

# download the source code
wget https://ftp.gromacs.org/gromacs/gromacs-2021.4.tar.gz



```

We then need to extract them.


```bash

# extract
tar xvf gromacs-2021.4.tar.gz


```

There should then be a directory called ``gromacs-2021.4``.
Move into that directory and create a new directory to build GROMACS in.

```bash
# move into the source code directory
cd gromacs-2021.4

# make the build directory
mkdir build
cd build

```


## Step 2: Configuration

We need to load the required modules on Discoverer, this chooses the compiler and MPI versions we will use.

```bash
# load the required modules
module purge
module load cmake 
module load fftw/3/3.3.10-gcc-openmpi
module load openmpi/4/gcc/latest
module load openblas/latest-gcc
```

GROMACS is built using the CMake build system.
This requires two main parts: the configuration part which detects various compilation options and generates Makefiles; the make part which uses the CMake generated Makefiles to compile the source code.

For the configuration part we need to give multiple options specific to the build we are doing on Discoverer

```bash
# cmake configuration
cmake .. -DCMAKE_INSTALL_PREFIX=$(pwd)/.. -DBUILD_SHARED_LIBS=OFF -DGMX_MPI=ON -DGMX_OPENMP=ON \
    -DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpicxx \
    
    -DGMX_FFT_LIBRARY=fftw3 -DFFTWF_LIBRARY=/opt/software/fftw/3/3.3.10-gcc-openmpi/lib/libfftw3f.so -DFFTWF_INCLUDE_DIR=/opt/software/fftw/3/3.3.10-gcc-openmpi/include


```
The above command will print out alot of information specifity the various settings CMake has detected and will be using.



## Step 3: Compilation, testing, and installation

- ### Compilation
If the CMake configuration step was successful then the compilation can be done using the ``make`` command. 

```bash
# build
make -j32
```
The number after the ``J`` flag tells it how many parallel process to use for the compilation which can speed it up.

There may be some compiler warnings printed, these can often be ignored, there should not be any errors. If there are errors you will have to go back to the configutation stage and try to resolve them.


- ### Testing
We can then test the build for correctness by running the regression tests, this can be slightly time consuming to run. But should be done in a few minutes.

The ``make check`` command will build and then run the test cases, checking them for correctness aganinst the regression tests downloaded in step 1. the ``make test`` command will run the built test cases.




```bash
# Optional: build and run the regression tests

make -j32 check
```



**NOTE**:
we have found that on Discover's front end login nodes three of the test cases fail numbers 70,71,72. This is due to a UCX warning that does not occur on the compute nodes. The warning can be silenced and the tests will pass by setting an environmental variable, or the tests can be run on a compute node.


### Install

The install stage copies the executable files to the destination we specified in the configuration

```bash
# install
make install

```


## Using a user built version of GROMACS 

After following the steps above the program will be installed in the folder called ``gromacs-2021.4``.

To use this version of GROMACS you first need to activate the environment

```bash 
source gromacs-2021.4/bin/gmxrc
```

You will now be able to use the various GROMACS commands such as
```
gmx_mpi mdrun 
gmx_mpi grompp
```
You can check it is using the version you have built and not one from a previous module load command by using the ``which`` command.
```bash
which gmx_mpi
```
And it will print something like ``~/discoverer_lesson/build/gromacs-2021.4/bin/gmx_mpi``.

### in Slurm scripts
To use this version that you have compiled yourself instead of the centrally installed versions you will need to replace the ``module load`` command in the example slurm script in the previous section as follows

Delete the line
```bash
module load gromacs/2021/2021.4-intel-nogpu-openmpi-gcc
```

Add the lines
```bash
module load fftw/3/3.3.10-gcc-openmpi
module load openmpi/4/gcc/latest
module load openblas/latest-gcc

source /your/path/gromacs-2021.4/gmxrc
```
where you need to make sure ``/your/path`` corresponds to the location of your gromacs folder.

## Different build options

### aocc + OpenMPI

If you wish to use aocc (AMD Optimizing C/C++ Compilers) instead of gcc then you will need to load the respective aocc modules instead of the gcc version.

```bash
module load fftw/3/3.3.10-aocc-openmpi
module load openmpi/4/aocc/latest
module load openblas/latest-aocc
```
and modify the fftw paths in the CMake configuration.

```
-DGMX_FFT_LIBRARY=fftw3 -DFFTWF_LIBRARY=/opt/software/fftw/3/3.3.10-aocc-openmpi/lib/libfftw3f.so -DFFTWF_INCLUDE_DIR=/opt/software/fftw/3/3.3.10-aocc-openmpi/include
```


### MPICH

If you wish to use MPICH instead of OpenMPI when you will need to replace the OpenMPI module with the MPICH module

```bash
module load fftw/3/3.3.10-gcc-mpich  
module load mpich/3/gcc/latest 
```
and modify the fftw paths in the CMake configuration.

```bash
-DGMX_FFT_LIBRARY=fftw3 -DFFTWF_LIBRARY=/opt/software/fftw/3/3.3.10-gcc-mpich/lib/libfftw3f.so -DFFTWF_INCLUDE_DIR=/opt/software/fftw/3/3.3.10-gcc-mpich/include
```
