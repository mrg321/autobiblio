*** Settings ***
Library          Process
Library          OperatingSystem
Resource         credentials.resource

*** Variables ***
${LCP_PASSPHRASE}    ${USUARIO}
${OUTPUT_FOLDER}    ${CURDIR}${/}results${/}decrypted
${INPUT_DIR}    ${CURDIR}${/}results${/}downloads

*** Test Cases ***
Transform All Downloaded Books
    ${download_dir}=    Set Variable    ${INPUT_DIR}
    ${output_dir}=    Set Variable    ${OUTPUT_FOLDER}
    ${input_dir_exists}=    Run Keyword And Return Status
    ...    Directory Should Exist    ${download_dir}
    IF    ${input_dir_exists}
        Create Directory    ${output_dir}
        Clean Temporary Conversion Files    ${output_dir}
        ${downloaded_files}=    List Files In Directory    ${download_dir}
        Should Not Be Empty    ${downloaded_files}    No files found in ${download_dir}
        ${python}=    Evaluate    sys.executable    modules=sys

        FOR    ${downloaded_file}    IN    @{downloaded_files}
            ${input_file}=    Set Variable    ${download_dir}${/}${downloaded_file}
            ${download_stem}    ${extension}=    Split Extension    ${downloaded_file}
            ${output_base}=    Set Variable    ${output_dir}${/}${download_stem}
            ${output_pdf}=    Set Variable    ${output_base}.pdf
            ${pdf_exists}=    Run Keyword And Return Status    File Should Exist    ${output_pdf}
            ${output_epub}=    Set Variable    ${output_base}.epub
            ${epub_exists}=    Run Keyword And Return Status    File Should Exist    ${output_epub}
            ${output_zip}=    Set Variable    ${output_base}.zip
            ${zip_exists}=    Run Keyword And Return Status    File Should Exist    ${output_zip}
            IF    ${pdf_exists} or ${epub_exists} or ${zip_exists}
                Log    \nSkipping ${input_file}: already converted    console=True
                Clean Temporary Conversion Files    ${output_dir}
            ELSE
                Log    \n***Transforming ${input_file}***    console=True
                TRY
                    ${result}=    Run Process
                    ...    ${python}
                    ...    -m
                    ...    standalone.lcpdedrmcommandline
                    ...    ${input_file}
                    ...    ${LCP_PASSPHRASE}
                    ...    ${output_base}
                    Should Be Equal As Integers    ${result.rc}    0
                    ...    lcpdedrm failed for ${downloaded_file}: ${result.stderr}
                FINALLY
                    Clean Temporary Conversion Files    ${output_dir}
                END
            END
        END
    ELSE
        Log    \nDownloads directory does not exist; skipping transformation: ${download_dir}    console=True
    END

*** Keywords ***
Clean Temporary Conversion Files
    [Arguments]    ${directory}
    @{temporary_files}=    List Files In Directory    ${directory}    pattern=*.tmp
    FOR    ${temporary_file}    IN    @{temporary_files}
        Remove File    ${directory}${/}${temporary_file}
    END
