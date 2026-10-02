#!/bin/bash
#SBATCH --job-name=cohort
#SBATCH --partition=courses
#SBATCH --account=binf6610.202710
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=1:00:00
#SBATCH --export=NONE
#SBATCH --output=logs/cohort_%A.out

source "${SLURM_SUBMIT_DIR}/conf/slurm.env"

export TMPDIR="/tmp/${SLURM_JOB_ID}"
mkdir -p "${TMPDIR}"
trap 'rm -rf "${TMPDIR}"' EXIT

export THREADS="${SLURM_CPUS_PER_TASK}"

module load miniconda3/25.9.1
source activate "${CONDA_ENV}"

bash "${PIPELINE_DIR}/run_pipeline.sh" "${SAMPLESHEET}" "${RUN_ROOT}"
