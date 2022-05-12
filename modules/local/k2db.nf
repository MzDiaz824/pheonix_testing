process KRAKEN2DB {

    input:

    output:
    path("*.tgz")                  , optional:true, emit: k2db

    script:
    """
    cd ./assets/databases
    ftp ftp.XXXXXXX
    cd directorynameifneeded
    binary
    get filename.k2d or mget *.k2d [ohter filenames...]
    bye
    """
}



