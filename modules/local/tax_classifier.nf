process DETERMINE_TAXA_ID {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(kraken_weighted)
    tuple val(meta), path(formatted_ani_file)
    path(taxa_file)

    output:
    tuple val(meta), path('*.tax'), emit: taxonomy

    script:
    """
    determine_taxID.sh -k $kraken_weighted -s $meta.id -f $formatted_ani_file -d $taxa_file 
    """
}
