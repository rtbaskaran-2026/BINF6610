#!/bin/bash
#SBATCH -A binf6610.202710
#SBATCH -p courses
#SBATCH -c 8 --mem=24G -t 01:00:00
#SBATCH -J variant-call-build
#SBATCH -o build-%j.out
set -euo pipefail

export APPTAINER_CACHEDIR=/scratch/${USER}/apptainer-cache
mkdir -p "${APPTAINER_CACHEDIR}" "/scratch/${USER}/containers"

cd "${SLURM_SUBMIT_DIR}"
apptainer build --force "/scratch/${USER}/containers/variant-call.sif" variant-call.def

apptainer exec --cleanenv "/scratch/${USER}/containers/variant-call.sif" samtools --version | head -2
