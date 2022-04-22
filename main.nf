#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/quaisar
========================================================================================
    Github : https://github.com/nf-core/quaisar
    Website: https://nf-co.re/quaisar
    Slack  : https://nfcore.slack.com/channels/quaisar
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

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { QUAISAR } from './workflows/quaisar'

//
// WORKFLOW: Run main nf-core/qtest analysis pipeline
//

/*workflow NFCORE_QTEST {
    QUAISAR ()
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
workflow {
    NFCORE_QUAISAR ()
}

w

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
