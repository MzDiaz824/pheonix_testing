process CALCULATE_ASSEMBLY_RATIO {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(taxa_file)
    path(quast_report)
    path(ncbi_database)

    output:
    tuple val(meta), path('*.txt'), emit: ratio

    script: // This script is bundled with the pipeline, in cdcgov/phoenix/bin/
    """
    calculate_assembly_ratio.sh -d $ncbi_database -q $quast_report -t $taxa_file -s $meta.id
    """
}
