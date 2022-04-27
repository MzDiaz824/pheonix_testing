include { GAMMA } from '../modules/nf-core/modules/gamma/main'
include { FASTP } from '../modules/nf-core/modules/fastp/main'
include { SPADES } from '../modules/nf-core/modules/spades/main'
include { QUAST } from '../modules/nf-core/modules/quast/main'
include { FASTANI } from '../modules/nf-core/modules/fastani/main'
include { MASH_DIST } from '../modules/nf-core/modules/mash/dist/main'
include { MLST } from '../modules/nf-core/modules/mlst/main'
include { KRAKEN2 } from '../modules/nf-core/modules/kraken2/main'
include { PROKKA } from '../modules/nf-core/modules/prokka/main'
include { BUSCO } from '../modules/nf-core/modules/busco/main'
include { KRONA } from '../modules/nf-core/modules/krona/main'

//local module
include { KRAKEN2_DB } from '../modules/local/kraken2db'

workflow SPADES_TO_END {
    
    KRONA_KRONADB ( ) //fetch krona dbs

    KRONA_KTIMPORTTAXONOMY ( Need map, KRONA_KRONADB.out.db, taxes.csv? (Nick to answer my question) ) 
    //confirm taxes.csv is what we need for Krona

    SPADES ( FASTP.out.reads, directry/file for aa HMMS for guided mode?)

    QUAST( SPADES.out.scaffolds, SPADES.out.contigs, true, SPADES.out.gfa, true )

    FASTANI ( SPADES.out.scaffolds, SPADES.out.scaffolds , reference file for query) //does mash occur before this?

    MASH_DIST ( reference file?, SPADES.out.scaffolds ) //where do these reference files come from?

    MLST ( SPADES.out.scaffolds ) 

    GAMMA ( SPADES.out.scaffolds )

    KRAKEN2_DB ( )

    KRAKEN2 (SPADES.out.scaffolds, KRAKEN2_DB.out.db) 

    PROKKA ( SPADES.out.scaffolds )

    BUSCO () //TBD
}