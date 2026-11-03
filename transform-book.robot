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
    Create Directory    ${output_dir}
    ${downloaded_files}=    List Files In Directory    ${download_dir}
    Should Not Be Empty    ${downloaded_files}    No files found in ${download_dir}
    ${python}=    Evaluate    sys.executable    modules=sys

    FOR    ${downloaded_file}    IN    @{downloaded_files}
        ${input_file}=    Set Variable    ${download_dir}${/}${downloaded_file}
        ${download_stem}    ${extension}=    Split Extension    ${downloaded_file}
        ${output_base}=    Set Variable    ${output_dir}${/}${download_stem}
        ${output_pdf}=    Set Variable    ${output_base}.pdf
        ${pdf_exists}=    Run Keyword And Return Status    File Should Exist    ${output_pdf}
        IF    ${pdf_exists}
            Log    Skipping ${input_file}: already converted to ${output_pdf}    console=True
        ELSE
            Log    Transforming ${input_file}    console=True
            ${result}=    Run Process
            ...    ${python}
            ...    -m
            ...    standalone.lcpdedrmcommandline
            ...    ${input_file}
            ...    ${LCP_PASSPHRASE}
            ...    ${output_base}
            Should Be Equal As Integers    ${result.rc}    0
            ...    lcpdedrm failed for ${downloaded_file}: ${result.stderr}
        END
    END
