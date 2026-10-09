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

# Week 4:

### Breakage 1: Ctrl-C/scancel mid-run, then -resume
started a smoke run, hit Ctrl-C while FASTQC and FASTP
were still in progress (0 of 3 each), then reran the identical
command with -resume.

[85/4dbefb] VALIDATE | 1 of 1 ✔
[44/b6590f] FASTQC (smoke_02) | 0 of 3
[f5/843ad1] FASTP (smoke_03) | 0 of 3
WARN: Killing running tasks (4)

Validate was cached, every other task ran again. 

### Breakage 2: reference given as a queue channel, BWA_MEM only
changed `BWA_MEM(FASTP.out.reads, ref, ref_index, bwa_index)`
to `BWA_MEM(FASTP.out.reads, channel.fromPath(params.ref), ref_index)`,
then ran the smoke dataset.

Error main.nf:40:5: Incorrect number of call arguments, expected 4 but received 3
│ 40 | BWA_MEM(FASTP.out.reads, channel.fromPath(params.ref), ref_index)
╰ | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ERROR ~ Script compilation failed

Zero samples ran. My BWA processes expects 4 and I only gave three and that caused an error from the beginning. 

### Breakage 3: backslash removed from \$(...) in a script block
In modules/publish.nf, changed `col[\$i]` to `col[$i]`
(removed one backslash) in the awk program, then ran the smoke dataset.

Error modules/publish.nf:23:54: i is not defined
│ 23 | awk -F, ‘NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
╰ | ^^
ERROR ~ Script compilation failed

no .command.sh, .command.err, or .command.run were
ever created for this failure. The compile error happened while
Nextflow was parsing and validating the script itself - no task ever reached execution

### Breakage 4: time = '2m' for HAPLOTYPECALLER on the first Explorer run
added `withName: 'HAPLOTYPECALLER' { time = '2m' }` to
the explorer profile in nextflow.config, submitted a fresh run
(no -resume) so HaplotypeCaller would genuinely execute.

10948362 nf-HAPLOT+ FAILED 00:01:19 00:02:00 12:0
Process `HAPLOTYPECALLER (NA12003)` terminated with an error exit status (140)


