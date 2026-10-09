#!/bin/bash
#SBATCH --job-name=nextflow-head
#SBATCH --partition=courses
#SBATCH --account=binf6610.202710
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=4:00:00
#SBATCH --output=logs/nextflow_%j.out

module load nextflow/25.04.6

export APPTAINER_CACHEDIR=/scratch/${USER}/apptainer-cache
export NXF_APPTAINER_CACHEDIR=/scratch/${USER}/apptainer-cache
mkdir -p "${APPTAINER_CACHEDIR}"

nextflow run ../main.nf -profile explorer -resume\
    --samplesheet /courses/BINF6610.202710/data/samplesheet-variant8.csv \
    --ref /courses/BINF6610.202710/data/refs/grch38-1000g/GRCh38_full_analysis_set_plus_decoy_hla.fa \
    --region chr20:1-10000000 \
    --outdir /scratch/${USER}/w4-run

