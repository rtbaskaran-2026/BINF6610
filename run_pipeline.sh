#!/bin/bash
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export RUN_STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

#SBATCH –job-name=assign1
#SBATCH –partition=courses
#SBATCH –account=binf6610
#SBATCH –mem-1G

# Stage 0 - Validate
# Stage 1 - QC metrics
# Stage 2 - Trim
# Stage 3 - Align
# Stage 4 - Postprocess
# Stage 5 - Quantify
# Stage 6 - Merge
# Stage 7 - Analyze
# Stage 8 - QC Report
# Stage 9 - Publish

# Setting defaults for the variables in case no value is given
REF=${REF:-/courses/BINF6610.202710/data/refs/grch38-1000g/GRCh38_full_analysis_set_plus_decoy_hla.fa}
REGION=${REGION:-chr20:1-10000000}
SHEET="$1"
OUT="$2"
LAST="${3:-}"

QC="${OUT}/qc_raw"; TRIM="${OUT}/trim"; ALN="${OUT}/align"
CNT="${OUT}/counts"; LOG="${OUT}/logs"; RES="${OUT}/results"
GVCF="${OUT}/GVCF"; VCF="${OUT}/vcf"
mkdir -p "$QC" "$TRIM" "$ALN" "$CNT" "$LOG" "$RES" "$GVCF" "$VCF"

log() {
	echo "$*" >&2
}

die() {
    echo "$*" >&2
    exit 65
}

stage_validate() { 
	local problems=0
	sample_ids=()
	while IFS=, read -r id cond rep lib_type r1 r2; do
	  sample_ids+=("$id")

    # Checks if R1 file is mission
    [[ -s "$r1" ]] || { echo "$id: R1 missing: $r1" >&2; (( ++problems )); }

    # Checks if a paired sample doesn't have the R2 file
    if [[ "$lib_type" == paired && ! -s "$r2" ]]; then
    echo "$id: paired but R2 missing or empty" >&2
    (( ++problems ))
    fi

    # Checks if R1 is truncated
    if ! gzip -t "$r1" 2>/dev/null; then
      echo "$id: R1 is truncated: $r1" >&2
    (( ++problems ))
    fi

    # Checks if R2 is truncated
    if [[ -s "$r2" ]] && ! gzip -t "$r2" 2>/dev/null; then
      echo "$id: R2 is truncated: $r2" >&2
      (( ++problems ))
    fi

  done < <(tail -n +2 "$SHEET")

  # Checks if there are duplicate ids
  duplicates=$(printf '%s\n' "${sample_ids[@]}" | sort | uniq -d)

  if [[ -n "$duplicates" ]]; then
      echo "duplicate sample_id(s): $duplicates" >&2
      (( ++problems ))
  fi

  (( problems == 0 )) || { echo "validation failed: $problems problem(s)" >&2; exit 65; }
  echo "validation passed" >&2
}

stage_qc_raw() {
  local id cond rep lt r1 r2 base
  while IFS=, read -r id cond rep lt r1 r2; do
    fastqc -q -o "$QC" "$r1" 2> "${LOG}/${id}.fastqc.log"
    [[ "$lt" != paired ]] || fastqc -q -o "$QC" "$r2" 2>> "${LOG}/${id}.fastqc.log"
    base=$(basename "$r1" .fastq.gz)
    [[ -s "${QC}/${base}_fastqc.zip" ]] || die "$id: fastqc produced no report"
    log "$id: fastqc produced"
  done < <(tail -n +2 "$SHEET")
}

stage_trim() {
    local id cond rep lt r1 r2 n
    while IFS=, read -r id cond rep lt r1 r2; do
        if [[ "$lt" == paired ]]; then
            fastp -i "$r1" -I "$r2" \
                  -o "${TRIM}/${id}_R1.fastq.gz" -O "${TRIM}/${id}_R2.fastq.gz" \
                  -j "${LOG}/${id}.fastp.json" -h "${LOG}/${id}.fastp.html" \
                  2> "${LOG}/${id}.fastp.log"
        else
            fastp -i "$r1" -o "${TRIM}/${id}_R1.fastq.gz" \
                  -j "${LOG}/${id}.fastp.json" -h "${LOG}/${id}.fastp.html" \
                  2> "${LOG}/${id}.fastp.log"
        fi

        # trimming can only remove reads. Zero left means something is wrong.
        n=$(gzip -dc "${TRIM}/${id}_R1.fastq.gz" | wc -l)
        (( n > 0 )) || die "$id: nothing survived trimming"
        log "$id: trimmed to $(( n / 4 )) reads"
    done < <(tail -n +2 "$SHEET")
}

stage_align() {
    local id cond rep lt r1 r2
    while IFS=, read -r id cond rep lt r1 r2; do
        if [[ "$lt" == paired ]]; then
            bwa mem -R "@RG\tID:${id}\tSM:${id}" "$REF" "${TRIM}/${id}_R1.fastq.gz" "${TRIM}/${id}_R2.fastq.gz" 2> "${LOG}/${id}.bwa.log"

        else
            bwa mem -R "@RG\tID:${id}\tSM:${id}" "$REF" "${TRIM}/${id}_R1.fastq.gz" 2> "${LOG}/${id}.bwa.log"

        fi | samtools sort -@ 2 -o "${ALN}/${id}.bam"

        samtools index "${ALN}/${id}.bam"

        [[ -s "${ALN}/${id}.bam" ]] || die "$id: bwa produced no BAM"
        log "$id: aligned"
    done < <(tail -n +2 "$SHEET")
}

stage_postprocess() {
    local id cond rep lt r1 r2
    while IFS=, read -r id cond rep lt r1 r2; do
        gatk MarkDuplicates \
          -I "${ALN}/${id}.bam" \
          -O "${ALN}/${id}.dedup.bam" \
          -M "${LOG}/${id}.dedup.metrics.txt" 2> "${LOG}/${id}.markdup.log"

        [[ -s "${ALN}/${id}.dedup.bam" ]] || die "$id: MarkDuplicates did not produce a BAM"
        samtools index "${ALN}/${id}.dedup.bam"
        log "$id: duplicates marked"
    done < <(tail -n +2 "$SHEET")
}

stage_quantify() {
    local id cond rep lt r1 r2
    while IFS=, read -r id cond rep lt r1 r2; do
        gatk HaplotypeCaller \
          -R "$REF" \
          -I "${ALN}/${id}.dedup.bam" \
          -O "${GVCF}/${id}.g.vcf.gz" \
          -L "$REGION" \
          -ERC GVCF  2> "${LOG}/${id}.gatk_haplotypecaller_vcf.log"

          [[ -s "${GVCF}/${id}.g.vcf.gz" ]] || die "$id: GCVF was not produced"
          log "$id: GCVF made"
    done < <(tail -n +2 "$SHEET")
}

stage_merge() {
    local id cond rep lt r1 r2
    local gvcf_args=()

    while IFS=, read -r id cond rep lt r1 r2; do
      gvcf_args+=(-V "${GVCF}/${id}.g.vcf.gz")
    done < <(tail -n +2 "$SHEET")

    gatk CombineGVCFs \
      -R "$REF" \
      "${gvcf_args[@]}" \
      -O "${VCF}/combined_samples.g.vcf.gz" 2> "${LOG}/gatk_combineGCVFs.log"

    [[ -s "${VCF}/combined_samples.g.vcf.gz" ]] || die "CombineGVCFs did not produce anything"

    gatk GenotypeGVCFs \
      -R "$REF" \
      -V "${VCF}/combined_samples.g.vcf.gz" \
      -O "${VCF}/combined_samples.vcf.gz" 2> "${LOG}/gatk_genotypeGCVFs.log"

    [[ -s "${VCF}/combined_samples.vcf.gz" ]] || die "GenotypeGVCFs did not produce anything"
    log "combined VCF created"
}

stage_analyze() {

    gatk VariantFiltration \
      -R "$REF" \
      -V "${VCF}/combined_samples.vcf.gz" \
      -O "${VCF}/cohort.filtered.vcf.gz" \
      --filter-expression "QD < 2.0 || QUAL < 30.0 || SOR > 3.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0" \
      --filter-name "GATK_Standard_SNP_Filter" 2> "${LOG}/gatk_variantfiltration.log"

    [[ -s "${VCF}/cohort.filtered.vcf.gz" ]] || die "no filtered vcf output"
    log "combined VCF filtered"
}

stage_qc_report() {
    multiqc -q -o "$RES" "$QC" "$LOG" 2> "${LOG}/multiqc.log"
    [[ -s "${RES}/multiqc_report.html" ]] || die "multiqc produced no report"
    log "QC report written"
}

stage_publish() {
    bash "${HERE}/lib/write_manifest.sh" "${RES}" "${SHEET}" "${REF}" "${REGION}"
}

STAGES=(validate qc_raw trim align postprocess quantify merge analyze qc_report publish)

n=0
for stage in "${STAGES[@]}"; do
    log "===== stage ${n} : ${stage} ====="
    "stage_${stage}"
    [[ "$stage" == "$LAST" ]] && break
    n=$(( n + 1 ))
done




