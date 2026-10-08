// Stage 2 · trim — adapters and low-quality tails.
process FASTP {
    tag "${meta.id}"
    container params.containers.fastp

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*_trimmed_R{1,2}.fastq.gz'), emit: reads
    path '*.fastp.json',                                emit: json

    script:
    if (meta.single_end) {
        """
        fastp -w ${task.cpus} \\
              -i ${reads[0]} \\
              -o ${meta.id}_trimmed_R1.fastq.gz \\
              -j ${meta.id}.fastp.json -h ${meta.id}.fastp.html
        """
    } else {
        """
        fastp -w ${task.cpus} \\
              -i ${reads[0]} -I ${reads[1]} \\
              -o ${meta.id}_trimmed_R1.fastq.gz -O ${meta.id}_trimmed_R2.fastq.gz \\
              -j ${meta.id}.fastp.json -h ${meta.id}.fastp.html
        """
    }
}
