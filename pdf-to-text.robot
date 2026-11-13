*** Settings ***
Documentation     Convierte los PDF y copia los EPUB de results/decrypted.
...               No falla si no hay archivos PDF ni EPUB.
Library           OperatingSystem
Library           Process
Library           Collections

*** Variables ***
${ROOT_DIR}       ${CURDIR}
${INPUT_DIR}      ${ROOT_DIR}${/}results${/}decrypted
${OUTPUT_FOLDER}     ${ROOT_DIR}${/}results${/}txt
${EPUB_OUTPUT_FOLDER}    ${ROOT_DIR}${/}results${/}epub
${CONVERTER}      ${ROOT_DIR}${/}vendor${/}docling${/}pdf2text-docling.py

*** Test Cases ***
Convertir todos los PDF a texto o copiar EPUB sin modificar
    [Documentation]    Convierte PDF a TXT y copia EPUB sin modificar a results/epub.
    ${input_dir_exists}=    Run Keyword And Return Status
    ...    Directory Should Exist    ${INPUT_DIR}
    @{pdf_failures}=    Create List
    IF    ${input_dir_exists}
        @{pdf_files}=    List Files In Directory    ${INPUT_DIR}    pattern=*.pdf    absolute=True
        @{epub_files}=    List Files In Directory    ${INPUT_DIR}    pattern=*.epub    absolute=True
        ${pdf_count}=    Get Length    ${pdf_files}
        ${epub_count}=    Get Length    ${epub_files}

        IF    ${pdf_count} > 0
            ${python}=    Evaluate    sys.executable    modules=sys
            File Should Exist    ${CONVERTER}
            Create Directory    ${OUTPUT_FOLDER}

            FOR    ${pdf}    IN    @{pdf_files}
                ${nombre}=    Evaluate    pathlib.Path($pdf).stem    modules=pathlib
                ${salida}=    Set Variable    ${OUTPUT_FOLDER}${/}${nombre}.txt
                ${error}=    Convertir PDF si hace falta    ${python}    ${pdf}    ${salida}
                IF    $error
                    Append To List    ${pdf_failures}    ${error}
                    Log    ${error}    level=WARN    console=True
                END
            END
        END

        IF    ${epub_count} > 0
            Create Directory    ${EPUB_OUTPUT_FOLDER}
            FOR    ${epub}    IN    @{epub_files}
                ${nombre}=    Evaluate    pathlib.Path($epub).name    modules=pathlib
                ${salida_epub}=    Set Variable    ${EPUB_OUTPUT_FOLDER}${/}${nombre}
                Log    \nCopiando ${epub} -> ${salida_epub}    console=True
                Copy File    ${epub}    ${salida_epub}
            END
        END

        IF    ${pdf_count} == 0 and ${epub_count} == 0
            Log    \nNo se encontraron archivos PDF ni EPUB en ${INPUT_DIR}; no hay nada que procesar.    console=True
        END
    ELSE
        Log    \nNo existe la carpeta de archivos descifrados; se omite la conversión: ${INPUT_DIR}    console=True
    END

    ${failure_count}=    Get Length    ${pdf_failures}
    IF    ${failure_count} > 0
        ${failure_summary}=    Catenate    SEPARATOR=\n    @{pdf_failures}
        Fail    Fallaron ${failure_count} conversiones de PDF:\n${failure_summary}
    END

*** Keywords ***
Convertir PDF si hace falta
    [Arguments]    ${python}    ${pdf}    ${salida}
    ${salida_status}    ${salida_size}=    Run Keyword And Ignore Error
    ...    Get File Size    ${salida}
    IF    $salida_status == "PASS" and $salida_size > 0
        Log    \nOmitiendo ${pdf}: ya existe ${salida}    console=True
        RETURN    ${EMPTY}
    END

    Log    \n***Convirtiendo ${pdf} -> ${salida}***    console=True
    ${process_status}    ${resultado}=    Run Keyword And Ignore Error
    ...    Run Process
    ...    ${python}
    ...    ${CONVERTER}
    ...    --input
    ...    ${pdf}
    ...    --output
    ...    ${salida}
    ...    cwd=${ROOT_DIR}
    ...    stdout=PIPE
    ...    stderr=PIPE
    IF    $process_status == "FAIL"
        RETURN    No se pudo iniciar la conversión de ${pdf}: ${resultado}
    END

    IF    ${resultado.rc} != 0
        ${error}=    Catenate    SEPARATOR=\n
        ...    Falló la conversión de ${pdf} (código ${resultado.rc}).
        ...    STDOUT:
        ...    ${resultado.stdout}
        ...    STDERR:
        ...    ${resultado.stderr}
        RETURN    ${error}
    END

    ${salida_status}    ${salida_size}=    Run Keyword And Ignore Error
    ...    Get File Size    ${salida}
    IF    $salida_status == "FAIL"
        RETURN    La conversión de ${pdf} terminó sin generar ${salida}: ${salida_size}
    END
    IF    ${salida_size} == 0
        RETURN    La conversión de ${pdf} generó un TXT vacío: ${salida}
    END

    RETURN    ${EMPTY}
