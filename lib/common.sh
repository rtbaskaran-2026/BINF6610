set -euo pipefail

REF=${REF:-/courses/BINF6610.202710/data/refs/grch38-1000g/GRCh38_full_analysis_set_plus_decoy_hla.fa}
REGION=${REGION:-chr20:1-10000000}

REF_DIR=${REF_DIR:-/courses/BINF6610.202710/data/refs/grch38}
INDEX=${INDEX:-${REF_DIR}/hisat2/genome}
GTF=${GTF:-${REF_DIR}/annotation.gtf}
FASTQ_ROOT=${FASTQ_ROOT:-/courses/BINF6610.202710/data}
CONDITION_REF=${CONDITION_REF:-Healthy}
THREADS=${THREADS:-4}
SORT_THREADS=${SORT_THREADS:-2}
ALIGN_THREADS=$(( THREADS > SORT_THREADS ? THREADS - SORT_THREADS : 1 ))

setup_dirs() {
    QC="${OUT}/qc_raw"; TRIM="${OUT}/trim"; ALN="${OUT}/align"
    CNT="${OUT}/counts"; LOG="${OUT}/logs"; RES="${OUT}/results"
    GVCF="${OUT}/GVCF"; VCF="${OUT}/vcf"
    mkdir -p "$QC" "$TRIM" "$ALN" "$CNT" "$LOG" "$RES" "$GVCF" "$VCF"
}

log() {
       	echo "$*" >&2
}

die() {
    echo "$*" >&2
    exit 65
}

# Temporary files go on the node's own local disk, not shared storage.
# $SLURM_TMPDIR is unset on Explorer, so name ours after the job id.
export TMPDIR="/tmp/${SLURM_JOB_ID}"
mkdir -p "${TMPDIR}"
trap 'rm -rf "${TMPDIR}"' EXIT

rows() {
    local sheet=$1 only=${2:-}
    awk -F, -v want="$only" -v root="$FASTQ_ROOT" '
        BEGIN { n = split("sample_id condition replicate library_type r1_fastq r2_fastq", need, " ") }
        NR == 1 {
            for (i = 1; i <= NF; i++) col[$i] = i
            for (i = 1; i <= n; i++)
                if (!(need[i] in col)) {
                    print "samplesheet has no column named " need[i] > "/dev/stderr"
                    exit 65
                }
            next
        }
        want != "" && $col["sample_id"] != want { next }
        {
            r1 = $col["r1_fastq"]; r2 = $col["r2_fastq"]
            if (r1 != "" && r1 !~ /^\//) r1 = root "/" r1
            if (r2 != "" && r2 !~ /^\//) r2 = root "/" r2
            print $col["sample_id"] "," $col["condition"] "," $col["replicate"] \
                  "," $col["library_type"] "," r1 "," r2
        }
    ' "$sheet"
}
