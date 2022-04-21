/*
========================================================================================
    Processes
========================================================================================
*/

// Need way to solve path issue ....some sort of config
//params.databases = "/scicomp/groups/OID/NCEZID/DHQP/CEMB/Nick_DIR/RANDOM-NF_OUTPUT/databases"
params.databases = "./bin/databases"

process database_check {

    input:
    path db_path

    output:

    script:
    """
        database_checker.sh db_path
    """
}

db_ch = Channel.fromPath( params.databases, checkIfExists: true )

workflow database_checker {
  database_check(db_ch)
}
