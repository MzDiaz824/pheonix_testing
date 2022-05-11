process KRAKEN2DB {

    input:

    output:
    path("*.tgz")                  , optional:true, emit: k2db

    script:
    """
    singularity pull docker://staphb/kraken2:latest
    """
}



