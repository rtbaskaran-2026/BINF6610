# RESOURCES.md

## Memory

Initial request: `--mem=4G`.

Actual usage, measured via `sacct` during BWA-MEM alignment against the
full GRCh38 reference:

10755542 FAILED 00:39:49 4G
10755542.0 CANCELLED+ 00:39:48 8157388K


The job was killed by Slurm for exceeding memory allocation of 4G; MaxRSS reached
~7.8 GB. bwa mem needs
about 6 GB to load the GRCh38 index.

Changed to `--mem=8G`.

JobID MaxRSS AveCPU
10759766.0 6750096K 00:19:26


8G gave comfortable headroom (peak ~6.75 GB) without further failures.

## CPU / threads

## CPU / threads

Requested `--cpus-per-task=4` for both 01_persample.sbatch and
02_cohort.sbatch.

Measured via `seff` on one completed array task:
CPU Utilized ÷ Job Wall-clock time = 441s / 293s ≈ 1.5, meaning only
about 1.5 of the 4 requested cores were kept busy on average across
this sample's stages 0-5


## What I set, and why

## What I set, and why

- `--mem=8G`, based on the measured ~6.75-7.8 GB peak specifically
  during BWA-MEM alignment (see Memory section above) — the per-sample
  seff summary alone would understate this, since it averages align's
  peak against lighter stages.
- `--cpus-per-task=4`, kept at this value since the pipeline's
  compute-heavy steps (bwa mem, samtools sort) do consume multiple
  cores when busy; 4 provides headroom without over-requesting on a
  shared partition.
