*** Settings ***
Documentation     Convierte los PDF y copia los EPUB de results/decrypted.
...               No falla si no hay archivos PDF ni EPUB.
Library           OperatingSystem
Library           Process

*** Variables ***
${ROOT_DIR}       ${CURDIR}
${INPUT_DIR}      ${ROOT_DIR}${/}results${/}decrypted
${OUTPUT_FOLDER}     ${ROOT_DIR}${/}results${/}txt
${EPUB_OUTPUT_FOLDER}    ${ROOT_DIR}${/}results${/}epub
${CONVERTER}      ${ROOT_DIR}${/}vendor${/}pymupdf4llm${/}convert_pdf_to_text.py

*** Test Cases ***
Convertir todos los PDF a texto o copiar EPUB sin modificar
    [Documentation]    Convierte PDF a TXT y copia EPUB sin modificar a results/epub.
    ${input_dir_exists}=    Run Keyword And Return Status
    ...    Directory Should Exist    ${INPUT_DIR}
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
                ${salida_existe}=    Run Keyword And Return Status    File Should Exist    ${salida}
                IF    ${salida_existe}
                    Log    \nOmitiendo ${pdf}: ya existe ${salida}    console=True
                ELSE
                    Log    \n***Convirtiendo ${pdf} -> ${salida}***    console=True
                    ${resultado}=    Run Process
                    ...    ${python}
                    ...    ${CONVERTER}
                    ...    --input
                    ...    ${pdf}
                    ...    --output
                    ...    ${salida}
                    ...    cwd=${ROOT_DIR}
                    ...    stdout=PIPE
                    ...    stderr=PIPE
                    Should Be Equal As Integers    ${resultado.rc}    0
                    ...    msg=Falló la conversión de ${pdf}\nSTDOUT:\n${resultado.stdout}\nSTDERR:\n${resultado.stderr}
                    File Should Exist    ${salida}
                    ${tamano}=    Get File Size    ${salida}
                    Should Be True    ${tamano} > 0    El TXT generado está vacío: ${salida}
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
