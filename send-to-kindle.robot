*** Settings ***
Documentation     Send unsent EPUB files to Kindle using the bundled Gmail SMTP sender.
...               Successfully sent files are marked in results/epub/.sent.
Library           Collections
Library           OperatingSystem
Library           Process
Resource          credentials.resource

*** Variables ***
${ROOT_DIR}       ${CURDIR}
${INPUT_DIR}      ${ROOT_DIR}${/}results${/}epub
${SENT_DIR}       ${INPUT_DIR}${/}.sent
${SENDER_SCRIPT}  ${ROOT_DIR}${/}vendor${/}send2kindle${/}send2kindle.py

*** Tasks ***
Send Pending EPUB Books To Kindle
    [Documentation]    Sends each EPUB once; files with a success marker are skipped.
    ${input_dir_exists}=    Run Keyword And Return Status
    ...    Directory Should Exist    ${INPUT_DIR}
    IF    ${input_dir_exists}
        File Should Exist    ${SENDER_SCRIPT}
        Should Not Be Empty    ${KINDLE_SENDER}    Set KINDLE_SENDER in credentials.resource.
        Should Not Be Empty    ${KINDLE_APP_PASSWORD}    Set KINDLE_APP_PASSWORD in credentials.resource.
        Should Not Be Empty    ${KINDLE_TARGET_EMAIL}    Set KINDLE_TARGET_EMAIL in credentials.resource.
        ${previous_log_level}=    Set Log Level    NONE
        Set Environment Variable    KINDLE_SENDER    ${KINDLE_SENDER}
        Set Environment Variable    KINDLE_APP_PASSWORD    ${KINDLE_APP_PASSWORD}
        Set Environment Variable    KINDLE_TARGET_EMAIL    ${KINDLE_TARGET_EMAIL}
        Set Log Level    ${previous_log_level}
        Create Directory    ${SENT_DIR}

        @{input_files}=    List Files In Directory    ${INPUT_DIR}    absolute=True
        ${python}=    Evaluate    sys.executable    modules=sys
        ${sent}=    Set Variable    ${0}
        ${skipped}=    Set Variable    ${0}
        ${failed_files}=    Create List

        FOR    ${input_file}    IN    @{input_files}
            ${is_epub}=    Run Keyword And Return Status
            ...    Should Match Regexp    ${input_file}    (?i)\.epub$
            IF    ${is_epub}
                ${file_name}=    Evaluate    pathlib.Path($input_file).name    modules=pathlib
                ${marker_file}=    Set Variable    ${SENT_DIR}${/}${file_name}.sent
                ${already_sent}=    Run Keyword And Return Status
                ...    File Should Exist    ${marker_file}

                IF    ${already_sent}
                    Log    Skipping ${input_file}: already marked as sent.
                    ${skipped}=    Evaluate    ${skipped} + 1
                ELSE
                    Log    Sending ${input_file} to Kindle.
                    ${result}=    Run Process
                    ...    ${python}
                    ...    ${SENDER_SCRIPT}
                    ...    ${input_file}
                    ...    timeout=5 mins
                    ...    stdout=PIPE
                    ...    stderr=STDOUT

                    IF    ${result.rc} == 0
                        Create File    ${marker_file}    Sent successfully.
                        ${sent}=    Evaluate    ${sent} + 1
                        Log    Sent and marked: ${input_file}
                    ELSE
                        ${failure}=    Set Variable
                        ...    ${input_file} (exit code ${result.rc}): ${result.stdout}
                        Append To List    ${failed_files}    ${failure}
                        Log    ${failure}    level=ERROR
                    END
                END
            END
        END

        ${failed_count}=    Get Length    ${failed_files}
        Log To Console
        ...    \nKindle send finished. Sent: ${sent}. Skipped: ${skipped}. Failed: ${failed_count}.
        Should Be Empty    ${failed_files}    Some EPUB files could not be sent: ${failed_files}
    ELSE
        Log    EPUB folder does not exist; skipping Kindle send: ${INPUT_DIR}    console=True
    END