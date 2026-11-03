*** Settings ***
Documentation    Removes old files directly inside selected results folders.
...              Preserves reports, nested folders, and Kindle sent markers.
Library          OperatingSystem

*** Variables ***
${RESULTS_DIR}    ${CURDIR}${/}results
${RETENTION_DAYS}    ${4}
@{CLEANUP_DIRS}    epub    pdf    txt    downloads    decrypted

*** Tasks ***
Clean Temporary Files
    [Documentation]    Removes old files directly inside the allowlisted results folders.
    Should Be True    ${RETENTION_DAYS} > 0    Retention must be greater than zero days.
    ${results_exist}=    Evaluate    pathlib.Path($RESULTS_DIR).is_dir()    modules=pathlib
    IF    ${results_exist}
        ${retention_seconds}=    Evaluate    ${RETENTION_DAYS} * 86400
        ${cutoff_time}=    Evaluate    time.time() - ${retention_seconds}    modules=time
        @{subdirs}=    List Directories In Directory    ${RESULTS_DIR}    absolute=True
        ${cleanup_dirs_found}=    Set Variable    ${0}
        FOR    ${subdir}    IN    @{subdirs}
            ${directory_name}=    Evaluate    pathlib.Path($subdir).name    modules=pathlib
            IF    $directory_name in $CLEANUP_DIRS
                ${cleanup_dirs_found}=    Evaluate    ${cleanup_dirs_found} + 1
                Log    Processing cleanup folder: ${subdir}
                @{files}=    List Files In Directory    ${subdir}    absolute=True
                FOR    ${file}    IN    @{files}
                    ${modified_time}=    Get Modified Time    ${file}    epoch
                    IF    ${modified_time} < ${cutoff_time}
                        Log    Removing old file: ${file} (modified at ${modified_time})
                        Remove File    ${file}
                    END
                END
            END
        END
        IF    ${cleanup_dirs_found} == 0
            Log    No cleanup folders found in ${RESULTS_DIR}; nothing to clean.
        END
    ELSE
        Log    Results directory not found at ${RESULTS_DIR}; nothing to clean.
    END
