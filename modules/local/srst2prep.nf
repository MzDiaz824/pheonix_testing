process SRST2_PREP {
    tag "$meta.id"


    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastq.gz"), optional:true, emit: reads


    script:
    """
    rename -n 's/(\w_).*_(T[0-9])_.*(.fastq.gz)/$1$2$3/' *.fastq.gz or //
    rename -n 's/(\w+_)\w+_\w+_(\w._)\w+(.\w+)/$1$2$3/' *.fastq.gz
    """

}
