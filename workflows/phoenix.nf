/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPhoenix.initialise(params, log)


// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config ] //removed , params.fasta to stop issue w/connecting to aws and igenomes not used
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters

//input on command line
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet/list not specified!' }

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK                                   } from '../subworkflows/local/input_check'
include { SPADES_LOCAL                                  } from '../modules/local/localspades'
include { BUSCO                                         } from '../modules/local/busco'
include { GAMMA_S                                       } from '../modules/local/gammas'
include { FASTP as FASTP_SINGLES                        } from '../modules/local/localfastp'
include { BBMAP_REFORMAT                                } from '../modules/local/contig_less500'
include { GAMMA_PREP                                    } from '../modules/local/gammaprep'
include { QUAST                                         } from '../modules/local/localquast'
include { FASTANI                                       } from '../modules/local/localfastani'
include { KRAKENTOOLS_KREPORT2MPA as KREPORT2MPA_TRIMD  } from '../modules/local/krakentools_kreport2mpa'
include { KRAKENTOOLS_KREPORT2MPA as KREPORT2MPA_ASMBLD } from '../modules/local/krakentools_kreport2mpa'
include { KRAKENTOOLS_MAKEKREPORT                       } from '../modules/local/krakentools_makekreport'
include { FORMAT_ANI                                    } from '../modules/local/format_ANI_best_hit'
include { KRAKEN_BEST_HIT                               } from '../modules/local/kraken_bh'
include { GATHERING_READ_QC_STATS                       } from '../modules/local/fastp_minimizer'
include { DETERMINE_TAXA_ID                             } from '../modules/local/tax_classifier'


/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { BBMAP_BBDUK                                             } from '../modules/nf-core/modules/bbmap/bbduk/main'
include { FASTP as FASTP_TRIMD                                    } from '../modules/nf-core/modules/fastp/main'
include { FASTQC as FASTQCTRIMD                                   } from '../modules/nf-core/modules/fastqc/main'
include { SRST2_SRST2 as SRST2_TRIMD_AR                           } from '../modules/nf-core/modules/srst2/srst2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_TRIMD                        } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_ASMBLD                       } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_ASMBLD_WEIGHTED              } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { MLST                                                    } from '../modules/nf-core/modules/mlst/main'
include { GAMMA as GAMMA_AR                                       } from '../modules/nf-core/modules/gamma/main'
include { PROKKA                                                  } from '../modules/nf-core/modules/prokka/main'
include { GAMMA as GAMMA_HV                                       } from '../modules/nf-core/modules/gamma/main'
include { MULTIQC                                                 } from '../modules/nf-core/modules/multiqc/main'
include { KRONA_KRONADB                                           } from '../modules/nf-core/modules/krona/kronadb/main'
include { KRONA_KTIMPORTTEXT as KRONA_KTIMPORTTEXT_1              } from '../modules/nf-core/modules/krona/ktimporttext/main'
include { KRONA_KTIMPORTTEXT                                      } from '../modules/nf-core/modules/krona/ktimporttext/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS                             } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow PHOENIX {

    ch_versions     = Channel.empty() // Used to collect the software versions
    ch_sra_list     = Channel.empty()
    spades_ch       = Channel.empty() // Used later to make new channel with single_end: true when scaffolds are created

    if(params.sra_file)
    {
        ch_sra_list = from.SRA(params.sra_file)
    }
    //
    // SUBWORKFLOW: Read in samplesheet/list, validate and stage input files
    //

    // Call in reads
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    // Remove PhiX reads
    BBMAP_BBDUK (
        INPUT_CHECK.out.reads, params.bbdukdb
    )
    ch_versions = ch_versions.mix(BBMAP_BBDUK.out.versions)

    // Trim and remove low quality reads
    FASTP_TRIMD (
        BBMAP_BBDUK.out.reads, true, true
    )
    ch_versions = ch_versions.mix(FASTP_TRIMD.out.versions)

    // Rerun on unpaired reads to get stats, nothing removed
    FASTP_SINGLES (
        FASTP_TRIMD.out.reads_fail, false, false
    )
    ch_versions = ch_versions.mix(FASTP_SINGLES.out.versions)

    // Script gathers data from jsons for pipeline stats file
    GATHERING_READ_QC_STATS(
        FASTP_TRIMD.out.json, FASTP_SINGLES.out.json
    )

    // Running Fastqc on trimmed reads
    FASTQCTRIMD (
        FASTP_TRIMD.out.reads
    )
    ch_versions = ch_versions.mix(FASTQCTRIMD.out.versions.first())

    // Idenitifying AR genes in trimmed reads
    SRST2_TRIMD_AR (
        FASTP_TRIMD.out.reads.map{ meta, reads -> [ [id:meta.id, single_end:meta.single_end, db:'gene'], reads, params.ardb]}
    )
    ch_versions = ch_versions.mix(SRST2_TRIMD_AR.out.versions)

    // Checking for Contamination in trimmed reads
    KRAKEN2_TRIMD (
        FASTP_TRIMD.out.reads, params.path2db, true, true
    )
    ch_versions = ch_versions.mix(KRAKEN2_TRIMD.out.versions)

    // Create mpa file
    KREPORT2MPA_TRIMD (
        KRAKEN2_TRIMD.out.report
    )
    ch_versions = ch_versions.mix(KREPORT2MPA_TRIMD.out.versions)

    // Assemblying into scaffolds
    SPADES_LOCAL (
        FASTP_TRIMD.out.reads
    )
    ch_versions = ch_versions.mix(SPADES_LOCAL.out.versions)
    spades_ch = SPADES_LOCAL.out.scaffolds.map{meta, scaffolds -> [ [id:meta.id, single_end:true], scaffolds]}

    // Removing scaffolds <500bp
    BBMAP_REFORMAT (
        spades_ch
    )
    ch_versions = ch_versions.mix(BBMAP_REFORMAT.out.versions)

    GAMMA_PREP (
        BBMAP_REFORMAT.out.reads
    )

    // Getting MLST scheme for taxa
    MLST (
        BBMAP_REFORMAT.out.reads
    )
    ch_versions = ch_versions.mix(MLST.out.versions)

    // Running gamma to identify hypervirulence genes in scaffolds
    GAMMA_HV (
        GAMMA_PREP.out.prepped, params.hvgamdb
    )
    ch_versions = ch_versions.mix(GAMMA_HV.out.versions)

    // Running gamma to identify AR genes in scaffolds
    GAMMA_AR (
        GAMMA_PREP.out.prepped, params.ardb
    )
    ch_versions = ch_versions.mix(GAMMA_AR.out.versions)

    GAMMA_S (
        GAMMA_PREP.out.prepped, params.gamdbpf
    )
    ch_versions = ch_versions.mix(GAMMA_S.out.versions)

    // Getting Assembly Stats
    QUAST (
        BBMAP_REFORMAT.out.reads
    )
    ch_versions = ch_versions.mix(QUAST.out.versions)

    // Checking single copy genes for assembly completeness 
    BUSCO (
        spades_ch, 'auto', [], []
    )
    ch_versions = ch_versions.mix(BUSCO.out.versions)

    // Getting species ID as back up for FastANI and checking contamination isn't in assembly
    KRAKEN2_ASMBLD (
        BBMAP_REFORMAT.out.reads, params.path2db, true, true
    )
    ch_versions = ch_versions.mix(KRAKEN2_ASMBLD.out.versions)

    // Create mpa file
    KREPORT2MPA_ASMBLD (
        KRAKEN2_ASMBLD.out.report
    )
    ch_versions = ch_versions.mix(KREPORT2MPA_ASMBLD.out.versions)

    // Getting Kraken best hit
    KRAKEN_BEST_HIT(
        KRAKEN2_ASMBLD.out.report
    )

    // Getting species ID as back up for FastANI and checking contamination isn't in assembly
    KRAKEN2_ASMBLD_WEIGHTED (
        BBMAP_REFORMAT.out.reads, params.path2db, true, true
    )
    ch_versions = ch_versions.mix(KRAKEN2_ASMBLD.out.versions)

    // Create weighted kraken report based on scaffold length
    KRAKENTOOLS_MAKEKREPORT (
        KRAKEN2_ASMBLD_WEIGHTED.out.classified_reads_assignment, params.ktaxmap
    )
    ch_versions = ch_versions.mix(KRAKENTOOLS_MAKEKREPORT.out.versions)

    // Getting species ID
    FASTANI (
        BBMAP_REFORMAT.out.reads, params.refs
    )
    ch_versions = ch_versions.mix(FASTANI.out.versions)

    // Reformat ANI headers
    FORMAT_ANI (
        FASTANI.out.ani
    )

    // Getting ID from either FastANI or if fails, from Kraken2
    DETERMINE_TAXA_ID(
        KRAKENTOOLS_MAKEKREPORT.out.kraken_weighted_report, FORMAT_ANI.out.ani_best_hit, params.taxa
    )

    KRONA_KRONADB ( )
    ch_versions = ch_versions.mix(KRONA_KRONADB.out.versions)

    KRONA_KTIMPORTTEXT (
        KRAKEN2_ASMBLD.out.report
    )
    ch_versions = ch_versions.mix(KRONA_KTIMPORTTEXT.out.versions)

    KRONA_KTIMPORTTEXT_1 (
        KRAKEN2_ASMBLD.out.report
    )
    ch_versions = ch_versions.mix(KRONA_KTIMPORTTEXT_1.out.versions)

    // Collecting the software versions
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )


    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowPhoenix.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQCTRIMD.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect()
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
