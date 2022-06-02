def VERSION = 'https://github.com/jenniferlu717/KrakenTools/commit/ff29ebc975b8416bceb1e3928f360ac098fbd0e3' // Version information not provided by tool on CLI

process KRAKENTOOLS_KREPORT2MPA {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::python=3.8.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(kraken_report)

    output:
    tuple val(meta), path('*.mpa'), emit: mpa
    path "versions.yml"           , emit: versions

    script: // This script is bundled with the pipeline, in phoenix/bin/
    """
    kreport2mpa.py \\
        --report-file ${kraken_report} \\
        --output ${meta.id}.mpa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        krakentools: $VERSION
    END_VERSIONS
    """
}