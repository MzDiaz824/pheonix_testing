process UNZIPFASTQ {
    tag "$name"
    publishDir "$params.outdir/$name/"
   // label 'process_medium'

    //conda (params.enable_conda ? "bioconda::bbmap=38.90" : null)
    /*container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bbmap:38.90--he522d1c_1' :
        'quay.io/biocontainers/bbmap:38.90--he522d1c_1' }"*/

    input:
    tuple val(name), file(readPairs)


    output:
    tuple val(meta), file('*.fastq'), emit: reads
    path('*.fastq'), emit: readyReads
    tuple val(meta), path('*.log')     , emit: log
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    gzip -c "${name}_R1_001.fastq.gz"  > "${name}_R1_001.fastq"
	gzip -c "${name}_R2_001.fastq.gz"  > "${name}_R2_001.fastq"
    """
}
