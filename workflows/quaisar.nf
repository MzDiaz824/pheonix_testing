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

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { QUAISAR } from '../workflows/quaisar'
//include { READ_RUN } from '../subworkflows/read_run'
//include { ASSEMBLY_RUN } from '../subworkflows/assembly_run'
//include { UPDATE_DB_DEPENDANTS } from '../subworkflows/update_DB_dependants'
//include { UPDATE_DBS } from '../subworkflows/update_DBs'
include { BBMAP_BBDUK } from '../modules/nf-core/modules/bbmap/bbduk/main'
include { UNZIPFASTQ } from '../modules/local/unzipfq/main'
include { FASTP } from '../modules/nf-core/modules/fastp/main'
include { BLAST } from '../modules/nf-core/modules/blast/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'
include { GUNZIP } from '../modules/nf-core/modules/gunzip/main'
include { SPADES } from '../modules/nf-core/modules/spades/main'
include { KRAKEN2 } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { KRONA } from '../modules/nf-core/modules/krona/main'
include { QUAST } from '../modules/nf-core/modules/quast/main'
include { MASHTREE } from '../modules/nf-core/modules/mashree/main'
include { MASH_DIST } from '../modules/nf-core/modules/mash/dist/main'
include { MLST } from '../modules/nf-core/modules/mlst/main'
include { PROKKA } from '../modules/nf-core/modules/prokka/main'
include { QUAST } from '../modules/nf-core/modules/quast/main'
//include { GAMMA } from '../modules/nf-core/modules/GAMMA/main'
//include { SRST2 } from '../modules/nf-core/modules/srst2/main'
//include { PYANI } from '../modules/nf-core/modules/pyani/main'
//include { BUSCO } from '../modules/nf-core/modules/busco/main'

========================================================================================
   Quaisar Help Function
========================================================================================
*/

def quaisHelp() {
	log.info """
	Usage 1: nextflow run quaisar.nf

	Filepath Options:
	--input_folder 			Enter as 'path_to_reads/*_R{1,2}.fastq.gz'

	Main Options:
	--outdir			Directory where results will be saved.
	--email				An e-mail address that will receive the summary.
	--name				Name chosen to represent the current pipeline run.

	Default Directories:
	//./Results/$name/config.sh			Path to directory to store config.sh file for individual run.
	./Results					Path to Quaisar output folders.
	//./quaisarLogs							Directory where quaisar run logs are stored.
	//./massSubs								Temporary directory for mass submissions.
	""".stripIndent()
}

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow QUAISAR {

    ch_versions = Channel.empty()
    input_reads_ch = Channel.fromFilePairs("${params.input_folder}/*_R{1,2}*.{fastq,fastq.gz,fq,fq.gz}", checkIfExists: true )
    // input_assemblies_ch = Channel.fromPath("${params.input_folder}/*.{fasta,fna}", checkIfExists: true )
    // input_SRAs_ch =

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        INPUT_CHECK.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

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
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

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
