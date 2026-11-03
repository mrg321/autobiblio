*** Settings ***
Library    Process
Library    OperatingSystem
Library    Collections
Resource         credentials.resource

*** Variables ***
${ROOT_DIR}       ${CURDIR}
${INPUT_DIR}      ${ROOT_DIR}${/}results${/}txt
${OUTPUT_FOLDER}     ${ROOT_DIR}${/}results${/}cleaned_articles
${CONVERTER}      ${ROOT_DIR}${/}vendor${/}paper2articles${/}getarticles.py
${MODEL}          gemini-3.8-flash

*** Test Cases ***
Procesar Archivos Pendientes
    Directory Should Exist    ${INPUT_DIR}
    File Should Exist    ${CONVERTER}
    Create Directory    ${OUTPUT_FOLDER}
    @{input_files}=    List Files In Directory    ${INPUT_DIR}    pattern=*    absolute=True
    Should Not Be Empty    ${input_files}    No se han encontrado archivos en ${INPUT_DIR}
    ${python}=    Evaluate    sys.executable    modules=sys
    ${failed_files}=    Create List

    FOR    ${input_file}    IN    @{input_files}
        ${nombre}=    Evaluate    pathlib.Path($input_file).stem    modules=pathlib
        ${article_output}=    Set Variable    ${OUTPUT_FOLDER}${/}${nombre}
        ${processed_marker}=    Set Variable    ${article_output}${/}.processed
        ${already_processed}=    Run Keyword And Return Status    File Should Exist    ${processed_marker}
        IF    ${already_processed}
            Log    Omitiendo ${input_file}: ya se procesó anteriormente
        ELSE
            Create Directory    ${article_output}
            ${result}=    Run Process
            ...    ${python}
            ...    ${CONVERTER}
            ...    ${input_file}
            ...    --api-key
            ...    ${API_KEY}
            ...    --model
            ...    ${MODEL}
            ...    --output-dir
            ...    ${article_output}
            ...    timeout=10 mins
            ...    stderr=STDOUT
            IF    ${result.rc} != 0
                ${failure}=    Set Variable    ${input_file} (código ${result.rc}): ${result.stdout}
                Append To List    ${failed_files}    ${failure}
                Log    ${failure}    level=ERROR
            ELSE
                @{articles}=    List Files In Directory    ${article_output}    pattern=*.json
                IF    not $articles
                    ${failure}=    Set Variable    ${input_file}: no se generaron artículos
                    Append To List    ${failed_files}    ${failure}
                    Log    ${failure}    level=ERROR
                ELSE
                    Create File    ${processed_marker}
                    Log    Proceso completado: ${input_file}
                END
            END
        END
    END
    Should Be Empty    ${failed_files}    Fallaron algunos archivos: ${failed_files}