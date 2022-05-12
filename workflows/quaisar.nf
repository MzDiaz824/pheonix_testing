/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowQuaisar.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

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
include { INPUT_CHECK } from '../subworkflows/local/input_check'
include { SPADES_LOCAL } from '../modules/local/localspades'
//include { SRST2_PREP } from '../modules/local/srst2prep'
//include { BUSCO_QC            } from '../subworkflows/local/busco_qc'              addParams( busco_db_options: params.modules['busco_db_prep'], busco_options: params.modules['busco'], busco_save_download_options: params.modules['busco_save_download'], busco_plot_options: params.modules['busco_plot'], busco_summary_options: params.modules['busco_summary'])


if(params.busco_reference){
    Channel
        .value(file( "${params.busco_reference}" ))
        .set { ch_busco_db_file }
} else {
    ch_busco_db_file = Channel.empty()
}
if (params.busco_download_path) {
    Channel
        .value(file( "${params.busco_download_path}" ))
        .set { ch_busco_download_folder }
} else {
    ch_busco_download_folder = Channel.empty()
}
/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { BBMAP_BBDUK                       } from '../modules/nf-core/modules/bbmap/bbduk/main'
include { FASTP                             } from '../modules/nf-core/modules/fastp/main'
include { FASTQC as FASTQCTRIMD             } from '../modules/nf-core/modules/fastqc/main'
include { SRST2_SRST2 as SRST2_TRIMD_AR     } from '../modules/nf-core/modules/srst2/srst2/main'
include { SRST2_SRST2 as SRST2_TRIMD_MLST   } from '../modules/nf-core/modules/srst2/srst2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_TRIMD  } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_ASMBLD } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { SPADES                            } from '../modules/nf-core/modules/spades/main'
include { QUAST                             } from '../modules/nf-core/modules/quast/main'
include { FASTANI                           } from '../modules/nf-core/modules/fastani/main'
include { MLST                              } from '../modules/nf-core/modules/mlst/main'
include { GAMMA as GAMMA_AR                 } from '../modules/nf-core/modules/gamma/main'
include { PROKKA                            } from '../modules/nf-core/modules/prokka/main'
include { GAMMA as GAMMA_REPL               } from '../modules/nf-core/modules/gamma/main'
include { MASHTREE                          } from '../modules/nf-core/modules/mashtree/main'
include { MULTIQC                           } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS       } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow QUAISAR {

    ch_versions = Channel.empty()

    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    BBMAP_BBDUK (
        INPUT_CHECK.out.reads, params.bbdukdb
    )
    ch_versions = ch_versions.mix(BBMAP_BBDUK.out.versions)

    FASTP (
        BBMAP_BBDUK.out.reads, true, true
    )
    ch_versions = ch_versions.mix(FASTP.out.versions)

    FASTQCTRIMD (
        FASTP.out.reads
    )

    ch_versions = ch_versions.mix(FASTQCTRIMD.out.versions.first())

    KRAKEN2_TRIMD (
        FASTP.out.reads, params.path2db, true, true
    )

    ch_versions = ch_versions.mix(KRAKEN2_TRIMD.out.versions)

    //below meta map update brings in <DataflowBroadcast around DataflowStream[?],>
    //in between file name and db name
    ar_ch  =  FASTP.out.reads.map{
                meta, meta1 ->
                def fmeta = [:]
                set meta.id
                fmeta.id = meta.id
                set meta.single_end
                fmeta.single_end = meta.single_end
                set meta.db
                fmeta.db = "gene"
                [fmeta, meta1, FASTP.out.reads, params.path2db] //params.ardb]
            }
            //.view()
    //cardinality error occurs using mapping above
    /*SRST2_TRIMD_AR (
        ar_ch
    )
    ch_versions = ch_versions.mix(SRST2_TRIMD_AR.out.versions)*/

    //need to know what db is used
    mlst_ch  =  FASTP.out.reads.map{
                meta, meta1 ->
                def fmeta = [:]
                set meta.id
                fmeta.id = meta.id
                set meta.single_end
                fmeta.single_end = meta.single_end
                set meta.db
                fmeta.db = "mlst"
                [fmeta, meta1, FASTP.out.reads, params.path2db] // params.ardb]
            }

    /*SRST2_TRIMD_MLST (
        mlst_ch
    )
    ch_versions = ch_versions.mix(SRST2_TRIMD_MLST.out.versions)*/

    //spades runs but the modules that require its input do
    //not recognize the spades output
    SPADES_LOCAL (
        FASTP.out.reads
    )
    ch_versions = ch_versions.mix(SPADES_LOCAL.out.versions)

    //ch_versions = ch_versions.mix(BUSCO_DB_PREPARATION.out.versions)
    //prokka_map = prokka_map.map{SPADES_LOCAL.out.scaffolds, }
    //if (!params.proteins)
    PROKKA (
        SPADES_LOCAL.out.scaffolds, [], []
    )
    ch_versions = ch_versions.mix(PROKKA.out.versions)

    /*if (!params.skip_busco){
            /*
            * BUSCO subworkflow: Quantitative measures for the assessment of genome assembly
            */
            /*BUSCO_QC (
                ch_busco_db_file,
                ch_busco_download_folder,
                PROKKA.out.faa
                //METABAT2_BINNING.out.bins.transpose()
            )
            //ch_busco_summary = BUSCO_QC.out.summary
            //ch_busco_multiqc = BUSCO_QC.out.multiqc
            //ch_software_versions = ch_software_versions.mix(BUSCO_QC.out.version.first().ifEmpty(null))
            // process information if BUSCO analysis failed for individual bins due to no matching genes
            BUSCO_QC.out
                .failed_bin
                .splitCsv(sep: '\t')
                .map { bin, error -> if (!bin.contains(".unbinned.")) busco_failed_bins[bin] = error }
        }*/
    //ch_versions = ch_versions.mix(BUSCO_QC.out.versions)

    QUAST (
        SPADES_LOCAL.out.scaffolds, SPADES_LOCAL.out.contigs, false, PROKKA.out.gff, false
    )
    ch_versions = ch_versions.mix(QUAST.out.versions)

    KRAKEN2_ASMBLD (
        SPADES_LOCAL.out.scaffolds, params.path2db, true, true
    )
    ch_versions = ch_versions.mix(KRAKEN2_ASMBLD.out.versions)

    MASHTREE (
        SPADES_LOCAL.out.scaffolds
    )
    ch_versions = ch_versions.mix(KRAKEN2_ASMBLD.out.versions)

    FASTANI (
        SPADES_LOCAL.out.scaffolds, params.ani_db
    )
    ch_versions = ch_versions.mix(FASTANI.out.versions)

    MLST (
        SPADES_LOCAL.out.scaffolds
    )
    ch_versions = ch_versions.mix(MLST.out.versions)

    /*GAMMA_AR (
        SPADES_LOCAL.out.scaffolds, params.path2db //will this run like kraken2 where it will pull all dbs?
    )*/


    GAMMA_REPL (
        SPADES_LOCAL.out.scaffolds, params.path2db // params.gamdbpf
    )
    ch_versions = ch_versions.mix(GAMMA_REPL.out.versions)


    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowQuaisar.paramsSummaryMultiqc(workflow, summary_params)
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
