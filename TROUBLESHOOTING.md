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
