// Check mandatory parameters

include { FASTQC } from '../modules/nf-core/modules/fastp/main'
workflow RAW_READ_QC {
    FASTQC ( FASTP.out.reads )
    //MULTIqc??
}