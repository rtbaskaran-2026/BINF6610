## Base image
mambaorg/micromamba:2.0.5-ubuntu24.04

## Versions pinned
bwa=0.7.19 samtools=1.24 bcftools=1.24 gatk4=4.6.2.0 fastqc=0.12.1 fastp=1.3.7 multiqc=1.35 git=2.47.1

## The pushed image
built from containers/variant-call.def by job 10773394

To rerun this in a year: clone this repository, and on Explorer run
`sbatch containers/build.sbatch` from inside `containers/` to rebuild
the .sif from the recipe. There is no registry digest for this build —
it was built directly with Apptainer rather than pushed through Docker
Hub, since Docker was not available on the build machine. The `.sif`
itself is deleted from `/scratch` on the first Tuesday of every month,
and bioconda may resolve slightly different dependency versions on a
future rebuild even with the same pins, so a rebuild is not guaranteed
to be byte-identical to this one. The "Versions pinned" heading above
is what to match against if verifying a future rebuild.
