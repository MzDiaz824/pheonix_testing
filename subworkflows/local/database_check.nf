/*
// Check database location for most up to date versions and updates if necessary
*/

process database_check {

    input:
    path(db_path)

    output:

    script:
    """
        database_checker.sh ${db_path}
    """
}
