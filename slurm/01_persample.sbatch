#!/bin/bash
#SBATCH --job-name=persample
#SBATCH --partition=courses
#SBATCH --account=binf6610.202710
#SBATCH --array=1-8
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=1:00:00
#SBATCH --export=NONE
#SBATCH --output=logs/persample_%A_%a.out

source "${SLURM_SUBMIT_DIR}/conf/slurm.env"

export TMPDIR="/tmp/${SLURM_JOB_ID}"
mkdir -p "${TMPDIR}"
trap 'rm -rf "${TMPDIR}"' EXIT

export THREADS="${SLURM_CPUS_PER_TASK}"

module load miniconda3/25.9.1
source activate "${CONDA_ENV}"

SAMPLE=$(awk -F',' -v n="${SLURM_ARRAY_TASK_ID}" 'NR == n + 1 { print $1 }' "${SAMPLESHEET}")
[[ -n "${SAMPLE}" ]] || { echo "task ${SLURM_ARRAY_TASK_ID}: no row ${SLURM_ARRAY_TASK_ID} in ${SAMPLESHEET}" >&2; exit 64; }

bash "${PIPELINE_DIR}/run_sample.sh" "${SAMPLESHEET}" "${RUN_ROOT}" "${SAMPLE}"
