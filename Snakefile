import csv
import os
import re

from snakemake.utils import min_version

min_version("9.0")

configfile: "config.yaml"

KNOWN = {"samplesheet", "ref", "region", "outdir", "platform", "executor", "containers"}
unknown = sorted(set(config) - KNOWN)
if unknown:
    raise ValueError(f"unknown config key(s): {', '.join(unknown)}")

PIPELINE = {"name": "variant-call", "version": "1.0.0"}
OUT = config["outdir"]
BIN = os.path.join(workflow.basedir, "bin")       # bin/ is not on the PATH: call scripts by their path
IMAGES = {name: f"docker://{image}" for name, image in config["containers"].items()}

REF = config["ref"]                                                     # the FASTA
REF_FAI = REF + ".fai"
REF_BWA = [REF + ext for ext in (".amb", ".ann", ".bwt", ".pac", ".sa")]  # bwa's index
REF_DICT = os.path.splitext(REF)[0] + ".dict"                           # smoke.dict, not smoke.fa.dict

SHEET = config["samplesheet"]
with open(SHEET) as fh:
    ROWS = list(csv.DictReader(fh))
SAMPLES = [row["sample_id"] for row in ROWS]
PAIRED = [row["sample_id"] for row in ROWS if row["library_type"] == "paired"]
SINGLE = [row["sample_id"] for row in ROWS if row["library_type"] == "single"]

def resolve(path):
    return path if os.path.isabs(path) else os.path.join(os.path.dirname(SHEET), path)

READS = {
    row["sample_id"]: [resolve(row["r1_fastq"])]
    + ([resolve(row["r2_fastq"])] if row["library_type"] == "paired" else [])
    for row in ROWS
}


def one_of(names):
    """A wildcard pattern matching exactly
    these sample names, or nothing at all."""
    return "|".join(map(re.escape, names)) \
        if names else "(?!)"



rule all:
    input:
        f"{OUT}/cohort.filtered.vcf.gz",
        f"{OUT}/variants.tsv",
        f"{OUT}/multiqc_report.html",
        f"{OUT}/samples.tsv",
        f"{OUT}/manifest.json",




# Stage 0 · validate — the samplesheet, every FASTQ, the reference and its
# indexes, before anything computes. A rule must make a file, so this one
# makes a copy of the samplesheet; every per-sample rule takes that copy as
# an input, which is what makes them all wait until validation has passed.

rule validate:
    input:
        sheet=SHEET,
        fastqs=[fq for reads in READS.values() for fq in reads],
        ref=REF,
        ref_index=[REF_FAI] + REF_BWA,
        ref_dict=REF_DICT,
    output:
        "work/validate/samplesheet.csv",
    log:
        "logs/validate.log",
    container: IMAGES["tools"]
    shell:
        "({BIN}/validate_samplesheet.sh {input.sheet} {input.ref} {REF_FAI} {input.ref_dict} && cp {input.sheet} {output}) 2> {log}"


def trimmed(wildcards):
    """The trimmed reads of one sample: one file if single-end, two if paired."""
    s = wildcards.sample
    if s in PAIRED:
        return [f"work/trim/{s}_R1.trim.fastq.gz", f"work/trim/{s}_R2.trim.fastq.gz"]
    return [f"work/trim/{s}_R1.trim.fastq.gz"]

# Stage 1 · qc_raw — FastQC on the reads as they arrived.
rule fastqc:
    input:
        reads=lambda wc: READS[wc.sample],
        checked=rules.validate.output,
    output:
        directory("work/fastqc/{sample}"),
    threads: 4
    log:
        "logs/fastqc/{sample}.log",
    container: IMAGES["fastqc"]
    shell:
        "(mkdir -p {output} && fastqc -q -t {threads} -o {output} {input.reads}) 2> {log}"


# Stage 2 · trim. Two rules, because a rule's outputs are fixed: a paired
# sample makes two trimmed files and a single-end sample makes one.
rule fastp_paired:
    input:
        r1=lambda wc: READS[wc.sample][0],
        r2=lambda wc: READS[wc.sample][1],
        checked=rules.validate.output,
    output:
        r1="work/trim/{sample}_R1.trim.fastq.gz",
        r2="work/trim/{sample}_R2.trim.fastq.gz",
        json="work/trim/{sample}.fastp.json",
        html="work/trim/{sample}.fastp.html",
    wildcard_constraints:
        sample=one_of(PAIRED),
    threads: 4
    log:
        "logs/fastp/{sample}.log",
    container: IMAGES["fastp"]
    shell:
        "fastp -w {threads} -i {input.r1} -I {input.r2} -o {output.r1} -O {output.r2}"
        " -j {output.json} -h {output.html} 2> {log}"


rule fastp_single:
    input:
        r1=lambda wc: READS[wc.sample][0],
        checked=rules.validate.output,
    output:
        r1="work/trim/{sample}_R1.trim.fastq.gz",
        json="work/trim/{sample}.fastp.json",
        html="work/trim/{sample}.fastp.html",
    wildcard_constraints:
        sample=one_of(SINGLE),
    threads: 4
    log:
        "logs/fastp/{sample}.log",
    container: IMAGES["fastp"]
    shell:
        "fastp -w {threads} -i {input.r1} -o {output.r1} -j {output.json} -h {output.html} 2> {log}"


# Stage 3 · align — BWA-MEM straight into a sorted, indexed BAM.
rule bwa_mem:
    input:
        reads=trimmed,
        ref=REF,
        ref_index=[REF_FAI] + REF_BWA,
    output:
        bam="work/align/{sample}.bam",
        bai="work/align/{sample}.bam.bai",
    wildcard_constraints:
        sample="|".join(map(re.escape, SAMPLES)),
    params:
        reads=lambda wc, input: " ".join(input.reads),
    threads: 8
    log:
        "logs/bwa_mem/{sample}.log",
    container: IMAGES["bwa"]
    shell:
        """
        (bwa mem -t {threads} -R "@RG\\tID:{wildcards.sample}\\tSM:{wildcards.sample}" {input.ref} {params.reads} \
            | samtools sort -@ 2 -o {output.bam}
         samtools index {output.bam}) 2> {log}
        """


# Stage 4 · postprocess — mark duplicates.
rule markduplicates:
    input:
        bam="work/align/{sample}.bam",
        bai="work/align/{sample}.bam.bai",
    output:
        bam="work/align/{sample}.dedup.bam",
        bai="work/align/{sample}.dedup.bam.bai",
        metrics="work/align/{sample}.dedup.metrics.txt",
    log:
        "logs/markduplicates/{sample}.log",
    container: IMAGES["gatk"]
    shell:
        """
        (gatk MarkDuplicates -I {input.bam} -O {output.bam} -M {output.metrics}
         samtools index {output.bam}) 2> {log}
        """


# Stage 5 · quantify — per-sample variant calling into a GVCF.
rule haplotypecaller:
    input:
        bam="work/align/{sample}.dedup.bam",
        bai="work/align/{sample}.dedup.bam.bai",
        ref=REF,
        ref_index=[REF_FAI] + REF_BWA,
        ref_dict=REF_DICT,
    output:
        gvcf="work/gvcf/{sample}.g.vcf.gz",
        tbi="work/gvcf/{sample}.g.vcf.gz.tbi",
    params:
        region=config["region"],
    threads: 8
    log:
        "logs/haplotypecaller/{sample}.log",
    container: IMAGES["gatk"]
    shell:
        "gatk HaplotypeCaller -R {input.ref} -I {input.bam} -O {output.gvcf}"
        " -L {params.region} -ERC GVCF --native-pair-hmm-threads {threads} 2> {log}"


# Stage 6 · merge — joint genotyping across the whole cohort.
# This is the barrier: expand() lists one GVCF per sample in the samplesheet,
# so this rule cannot run until every sample has been called.
rule joint_genotype:
    input:
        gvcfs=expand("work/gvcf/{sample}.g.vcf.gz", sample=SAMPLES),
        tbis=expand("work/gvcf/{sample}.g.vcf.gz.tbi", sample=SAMPLES),
        ref=REF,
        ref_index=[REF_FAI] + REF_BWA,
        ref_dict=REF_DICT,
    output:
        combined="work/vcf/combined.g.vcf.gz",
        vcf="work/vcf/cohort.vcf.gz",
    params:
        variants=lambda wc, input: " ".join(f"-V {g}" for g in input.gvcfs),
        region=config["region"],
    log:
        "logs/joint_genotype.log",
    container: IMAGES["gatk"]
    shell:
        """
        (gatk CombineGVCFs -R {input.ref} {params.variants} -O {output.combined}
         gatk GenotypeGVCFs -R {input.ref} -V {output.combined} -O {output.vcf} -L {params.region}) 2> {log}
        """


# Stage 7 · analyze — hard-filter the cohort VCF, and summarize it as a table.
rule filter:
    input:
        vcf="work/vcf/cohort.vcf.gz",
        ref=REF,
        ref_index=[REF_FAI] + REF_BWA,
        ref_dict=REF_DICT,
    output:
        vcf=f"{OUT}/cohort.filtered.vcf.gz",
        tbi=f"{OUT}/cohort.filtered.vcf.gz.tbi",
        table=f"{OUT}/variants.tsv",
    log:
        "logs/filter.log",
    container: IMAGES["gatk"]
    shell:
        r"""
        (gatk VariantFiltration -R {input.ref} -V {input.vcf} -O {output.vcf} \
            --filter-expression "QD < 2.0 || QUAL < 30.0 || SOR > 3.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0" \
            --filter-name "GATK_Standard_SNP_Filter"
         printf 'chrom\tpos\tref\talt\tqual\tfilter\n' > {output.table}
         bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t%FILTER\n' {output.vcf} >> {output.table}) 2> {log}
        """


# Stage 8 · qc_report — one report across the cohort.
rule multiqc:
    input:
        expand("work/fastqc/{sample}", sample=SAMPLES),
        expand("work/trim/{sample}.fastp.json", sample=SAMPLES),
    output:
        f"{OUT}/multiqc_report.html",
    log:
        "logs/multiqc.log",
    container: IMAGES["multiqc"]
    shell:
        "(multiqc -q -f -o work/multiqc {input} && cp work/multiqc/multiqc_report.html {output}) 2> {log}"


# Stage 9 · publish — the course's rules/publish.smk, unchanged.
PUBLISH_SHEET = rules.validate.output
PUBLISH_RESULTS = [*rules.filter.output, *rules.multiqc.output]
include: "rules/publish.smk"
