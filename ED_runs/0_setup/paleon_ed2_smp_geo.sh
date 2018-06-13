#!/bin/sh
#$ -wd /dummy/path
#$ -j y 
#$ -S /bin/bash         
#$ -V 
#$ -pe omp 4
#$ -v OMP_NUM_THREADS=4
#$ -l h_rt=48:00:00
#$ -N TEST
#cd /dummy/path
./ed_2.1-opt
