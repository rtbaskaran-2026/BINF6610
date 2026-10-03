# Used Claude to help with debugging

1) For my validate function, I had trouble with the check: if its a paired sample but no R2. I initially used -n "$r2" && -s "$r2" as the check for this but that test case failed for me. When I changed it to lib_type == 'paired' && -s "$r2", it addressed these types of cases.  

2) Had trouble with the fastp and fastqc code. No error was printed and no output showed up underneath the ==stage== so I wasn't sure what was wrong. It was because those packages weren't installed so I used brew install. 

3) Same issue as about but with gatk, I needed to create a conda environment and install gatk. 

4) I had silly mistakes throughout: for example after -ERVC GVCF and before 2> I put a \ which caused no output

# WEEK 2

1) Memory undersized for BWA-MEM against the full reference

stage_align ran for ~40 minutes and then the job died. BWA-MEM needed ~7.8 GB to load the full
GRCh38 index, matching the assignment's own stated "~6 GB" figure. Slurm
killed the job for exceeding its allocation. I increased memory to 8 GB

2) fastp wrote a corrupt .tmp file under a .gz.tmp name

gzip -dc on the trimmed output failed with
not in gzip format, even though fastp's own log showed a clean,
successful run with real statistics. changed the resume-safe write pattern to keep .gz as the real
extension throughout

3) GVCF/VCF output directories never created

Only appeared when running through `run_sample.sh` via the Slurm array —
not during earlier interactive testing. added `GVCF="${OUT}/GVCF"; VCF="${OUT}/vcf"` and their `mkdir -p`
calls to `setup_dirs()`

### Breakage 1: the out-of-range task
**Command:** `sbatch --array=1-9 slurm/01_persample.sbatch`
**What happened:** task 9 correctly exited 64 rather than silently
processing no rows or the wrong row.

# Week 3
### 1. 02_cohort.sbatch called run_sample.sh instead of run_pipeline.sh
changed the final line to call run_pipeline.sh with no sample
argument, matching the original (pre-container) 02_cohort.sbatch.

### 2. THREADS and TMPDIR never reached the pipeline until exported explicitly
added `export THREADS="${SLURM_CPUS_PER_TASK}"` directly in
both job scripts, before the pipeline call, alongside the existing
TMPDIR export and trap.

### Breakage 3: --env THREADS removed, run one sample

By removing this line, THREADS never exported and so the fallback value for THREADS was activated. ALIGN_THREADS was = 4 and SORT_THREADS(2) = 2. Only half of the cores were actually used / four were asked for and we only used two.
CMD: bwa mem -t 2 -R @RG\tID:NA12878\tSM:NA12878 ... 

### Breakage 2: --bind removed, run one sample
The job failed almost immediately, no pipeline outputs except some error lines. The exit code was 1 and the path that couldn't be seen was /scratch/baskaran.aa. Removing the --bind line also broke the line
continuation joining it to the next argument, so apptainer exec
received zero arguments and printed its own usage error immediately. 

### Breakage 4: apptainer pull --arch arm64 ubuntu:24.04
the pull succeeded. The run said: 
FATAL: While checking container encryption: could not open image
.../arm.sif: the image's architecture (arm64) could not run on the
host's (amd64)
