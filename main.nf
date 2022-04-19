#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/qtest
========================================================================================
    Github : https://github.com/nf-core/qtest
    Website: https://nf-co.re/qtest
    Slack  : https://nfcore.slack.com/channels/qtest
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    DEFINE VALUES THAT CAN BE OVERWRITTEN
========================================================================================
*/
//FastQ files must be saved in the FASTQs folder
params.reads = "$baseDir/FASTQs/*_R{1,2}.fastq.gz"
params.bulkFastqBase = "$baseDir/MiSeqAnalysisFiles/reads2QC/*{R1,R2}_001.fastq"
//params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

//WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

//include { QTEST } from './workflows/qtest'
include { BBMAP_BBDUK } from './modules/nf-core/modules/bbmap/bbduk/main'
include { UNZIPFASTQ } from './modules/local/unzipfq/main'
include { FASTP } from './modules/nf-core/modules/fastp/main'
include { FASTQC } from './modules/nf-core/modules/fastqc/main'
include { GUNZIP } from './modules/nf-core/modules/gunzip/main'
include { SPADES } from './modules/nf-core/modules/spades/main'
include { QUAST } from './modules/nf-core/modules/quast/main'
include { FASTANI } from './modules/nf-core/modules/fastani/main'
include { MASH_DIST } from './modules/nf-core/modules/mash/dist/main'
include { MLST } from './modules/nf-core/modules/mlst/main'

//
// WORKFLOW: Run main nf-core/qtest analysis pipeline
//
/*workflow NFCORE_QTEST {
    QTEST ()
}*/
Channel
    .fromFilePairs( params.reads )
    //.ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    .set { readPairs }
Channel
    .fromPath( params.phiX )
    .set { phiX }

/*Channel
    .fromFilePairs( bulkFastqBase )
    .ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    .set { tounzip }*/

/*if ( params.bbmap_adapters ){
    bbmap_adapters = file("${params.bbmap_adapters}")
}*/
/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
/*workflow {
    NFCORE_QTEST ()
}*/

workflow {

    BBMAP_BBDUK(readPairs, phiX)
    //process is called like a function in the workflow block
    //UNZIPFASTQ(tounzip)

    FASTP( BBMAP_BBDUK.out.reads, BBMAP_BBDUK.out.log, BBMAP_BBDUK.out.versions )

    GUNZIP( FASTP.out.reads )

    FASTQC( FASTP.out.reads )

    SPADES( FASTP.out.reads)

    /*Questions re: quast 1. Whether to use the provided gff reference annotation file
    2. What genome GFF file to use. Has to contain at least a non-empty string dummy value.
    3. Should we use the provided fasta reference genome file?
    4. Do we use scaffolds or contigs for the assembly file of interest?
    QUAST(SPADES.out., SPADES.out., , )*/

    FASTANI( SPADES.out.??) //does mash occur before this?

    MASH_DIST( queryfasta, SPADES.out.scaffolds ) //where do these come from?

    MLST( SPADES.out. ) //scaffolds or contigs assembly fasta file to run MLST?


}

/*
========================================================================================
                                    PROCESSES
========================================================================================
*/
//incase gunzip is problematic
/*process UNZIPFASTQ {
    tag "$name"
    publishDir "$params.outdir/$name/"
	publishDir "$params.outdir/reads2QC/", mode: 'copy'

    input:
    tuple val(name), file(data)

  	output:
    file "*.fastq"

  	script:
	  """
	  gzip -c "${name}_R1_001.fastq.gz"  > "${name}_R1_001.fastq"
	  gzip -c "${name}_R2_001.fastq.gz"  > "${name}_R2_001.fastq"
	  """
 }*/
workflow.onComplete {

   println ( workflow.success ? """
       Pipeline execution summary
       ---------------------------
       Completed at: ${workflow.complete}
       Duration    : ${workflow.duration}
       Success     : ${workflow.success}
       workDir     : ${workflow.workDir}
       Exit status : ${workflow.exitStatus}
       """ : """
       Failed: ${workflow.errorReport}
       Exit status : ${workflow.exitStatus}
       """
   )
}
