/*
========================================================================================
    PARAMETERS & CHANNELS
========================================================================================
*/

//def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

/*
========================================================================================
   Pipeline Details
========================================================================================
*/

println"""/n
         Q U A I S A R - H - N F   P I P E L I N E
         ===================================
         Quaisar Description here
		 Author: Maria Diaz 
		 Email: lex0@cdc.gov
		 Version: 1.0.0
		""".stripIndent()
println"""/n
         =====================================================================================================================================
                                                       U S A G E   
         =====================================================================================================================================
		 reads        : ${params.reads}
         outdir       : ${params.outdir}
            """.stripIndent()
//documenting what versions we need
/*println"""/n
         =====================================================================================================================================
                                                       T O O L S : P R O C E S S E S  
         =====================================================================================================================================
*/


/*def quaisHelp() {
	log.info """
	Usage 1: nextflow run quaisar.nf 
	
	Filepath Options:
	--reads 			Enter as 'path_to_reads/*_R{1,2}.fastq.gz'

	Main Options:
	--outdir			Directory where results will be saved.
	--email				An e-mail address that will receive the summary.
	--name				Name chosen to represent the current pipeline run.

	Default Directories:
	./FASTQs                                Location to drag and drop FASTQs to be analyzed.
    ./MiSeqAnalysisFiles/config.sh			Path to directory to store config.sh file for individual run.
	./MiSeqAnalysisFiles					Path to Quaisar output folders.
	./quaisarLogs							Directory where quaisar run logs are stored.
	./massSubs								Temporary directory for mass submissions.		
	""".stripIndent()
}*/



/*WorkflowQuaisar.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
*/
// Check mandatory parameters
if (params.reads) { raw_reads = Channel.fromPath(params.reads) } else { exit 1, 'Please move your FASTQ files to the "FASTQs" folder!' }

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

//ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
//ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES
========================================================================================
*/
//include { UNZIPFASTQ } from '../modules/local/unzipfq/main'

/*
========================================================================================
    IMPORT LOCAL SUBWORKFLOWS
========================================================================================
*/

//include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'
//include { READ_RUN } from '../subworkflows/read_run'
//include { ASSEMBLY_RUN } from '../subworkflows/assembly_run'
//include { UPDATE_DB_DEPENDANTS } from '../subworkflows/update_DB_dependants'
//include { UPDATE_DBS } from '../subworkflows/update_DBs'
//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
//include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

// MODULE: Installed directly from nf-core/modules



include { BBMAP_BBDUK } from '../modules/nf-core/modules/bbmap/bbduk/main'
include { FASTP } from '../modules/nf-core/modules/fastp/main'
include { BLAST } from '../modules/nf-core/modules/blast/main'
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
include { FASTANI } from '../modules/nf-core/modules/quast/main'
include { FASTQC } from '../modules/nf-core/modules/fastqc/main'
include { GAMMA } from '../modules/nf-core/modules/gamma/main'
include { SEQKIT_PAIR } from '../modules/nf-core/modules/seqkit/pair/main'

//include { SRST2 } from '../modules/nf-core/modules/srst2/main'
//PYANI DOES NOT EXIST AND THERE IS NO OPEN NF-CORE MODULE ISSUE SUGGESTING A BUILD IS IN PROGRESS
//include { PYANI } from '../modules/nf-core/modules/pyani/main'
//BUSCO build status TBD
//include { BUSCO } from '../modules/nf-core/modules/busco/main'

/*
========================================================================================
    IMPORT NF-CORE SUBWORKFLOWS
========================================================================================
*/

/*========================================================================================
   Quaisar Help Function
========================================================================================
*/

params.help = false //set to false as default
// Display help message
if (params.help){
	quaisHelp()
	exit 0
}
/*
========================================================================================
                                RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
//def multiqc_report = []

workflow QUAISAR {

    SEQKIT_PAIR ( raw_reads )

    BBMAP_BBDUK ( SEQKIT_PAIR.out.reads, phiX)
    
    //process is called like a function in the workflow block
    //UNZIPFASTQ(tounzip)

    FASTP ( BBMAP_BBDUK.out.reads, true, true )

    KRAKEN2 ( meta map, readPairs, directory of database) //raw reads

    SRST2 ( readPairs...) //TBD x 2 for AR and MLST

    GUNZIP (  ) //confusing may use script I wrote

    //FASTQC ( FASTP.out.reads )

    SPADES ( meta map, FASTP.out.reads, directry/file for aa HMMS for guided mode?)

    /*Questions re: quast 1. Whether to use the provided gff reference annotation file
    2. What genome GFF file to use. Has to contain at least a non-empty string dummy value.
    3. Should we use the provided fasta reference genome file?
    4. Do we use scaffolds or contigs for the assembly file of interest?
    */
    QUAST( SPADES.out.scaffolds, SPADES.out.contigs, true, SPADES.out.gfa, true )

    FASTANI ( SPADES.out. , SPADES.out.scaffolds , reference file for query) //does mash occur before this?

    MASH_DIST ( meta map, reference file, SPADES.out.scaffolds ) //where do these come from?

    MLST ( meta map, SPADES.out.scaffolds ) //scaffolds or contigs assembly fasta file to run MLST?

    GAMMA ()

    KRAKEN2 ( meta map, SPADES.out.scaffolds, directory of database) //Assembled

    PROKKA ()

    BUSCO () //TBD
    
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
