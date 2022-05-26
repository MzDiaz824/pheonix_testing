
/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { SRATOOLS_PREFETCH    } from '../../modules/local/sratools_prefetch'
include { SRATOOLS_FASTERQDUMP } from '../../modules/local/sratools_fasterqdump'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
//def multiqc_report = []

workflow SRA_GET_READS {

    ch_versions     =   Channel.empty()
    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //



    SRATOOLS_PREFETCH (
        sra_input
    )
    ch_versions = ch_versions.mix(SRATOOLS_PREFETCH.out.versions.first())

    SRATOOLS_FASTERQDUMP (
        SRATOOLS_PREFETCH.out.sra
    )
    ch_versions = ch_versions.mix(SRATOOLS_FASTERQDUMP.out.versions.first())

    emit:
    reads = SRATOOLS_FASTERQDUMP.out.reads     // channel: [ val(meta), [ reads ] ]
    versions = ch_versions                    // channel: [ versions.yml ]

/*
========================================================================================
    THE END
========================================================================================
*/
