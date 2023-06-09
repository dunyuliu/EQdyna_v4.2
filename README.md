# Inverting for Dynamic Stress Evolution with EQdyna

https://zenodo.org/badge/latestdoi/616756877

The repository hosts source code of EQdyna used in the article *Inverting for dynamic stress evolution on earthquake faults directly from seismic recordings* by Meng et al. (2023, in revision) to compute numerical Green's functions, forward rupture Model A, and checkerboard models. 

Note that a newer version of EQdyna v5 is under active development in the repository https://github.com/dunyuliu/EQdyna.git. Numerical Green's function computation will be added to EQdyna v5 soon. 

# Contents
* src_Green_function/ contains the code to compute numerical Green's functions used in the article. 100 CPUs are used for each Green's function and the simulations were run on Terra at TAMU (https://hprc.tamu.edu/wiki/Terra). Batch script runTERRA.slurm was used to compute numerical Green's functions for patchnumer from ia to ib with unit traction changes over x, y, z directions, respectively. 

* src_checkerboard3X3_vr3/ contains the source code to compute the checkerboard model with 3X3 patches in the article. 100 CPUs were used on Terra at TAMU. 

* src_smooth_ModelA/ contains the source code to compute the Model A in the article. 100 CPUs were used on Terra at TAMU. 
