*** Settings ***
Documentation     Convierte los Markdown/TXT de results/txt a EPUB en results/epub.
...               Omite los EPUB que ya existen. Ejecutar desde la raíz del proyecto.
Library           OperatingSystem
Library           Process
Library           Collections
Library           String

*** Variables ***
${INPUT_DIR}       ${CURDIR}${/}results${/}txt
${PDF_INPUT_DIR}   ${CURDIR}${/}results${/}decrypted
${OUTPUT_FOLDER}      ${CURDIR}${/}results${/}epub
${CONVERTER}       ${CURDIR}${/}vendor${/}pypandoc${/}md_to_epub.py

*** Test Cases ***
Convertir Todos Los Markdown A EPUB
    [Documentation]    Procesa archivos .md, .markdown y .txt; usa la primera página del PDF coincidente como portada.
    ${input_dir_exists}=    Run Keyword And Return Status
    ...    Directory Should Exist    ${INPUT_DIR}
    IF    ${input_dir_exists}
        File Should Exist         ${CONVERTER}
        Create Directory          ${OUTPUT_FOLDER}
        ${python}=    Evaluate    sys.executable    modules=sys

        @{archivos}=    List Files In Directory    ${INPUT_DIR}
        ${generados}=    Set Variable    ${0}
        ${omitidos}=     Set Variable    ${0}

        FOR    ${archivo}    IN    @{archivos}
            ${es_markdown}=    Run Keyword And Return Status
            ...    Should Match Regexp    ${archivo}    (?i)\.(md|markdown|txt)$

            IF    ${es_markdown}
                ${nombre_base}=    Evaluate    os.path.splitext($archivo)[0]    modules=os
                ${archivo_entrada}=    Join Path    ${INPUT_DIR}    ${archivo}
                ${archivo_salida}=     Join Path    ${OUTPUT_FOLDER}    ${nombre_base}.epub
                ${archivo_pdf}=    Join Path    ${PDF_INPUT_DIR}    ${nombre_base}.pdf
                @{argumentos}=    Create List
                ...    ${archivo_entrada}
                ...    -o
                ...    ${archivo_salida}
                ...    --title
                ...    ${nombre_base}
                ...    --toc

                ${pdf_existe}=    Run Keyword And Return Status
                ...    File Should Exist    ${archivo_pdf}
                IF    ${pdf_existe}
                    Append To List    ${argumentos}    --cover-pdf    ${archivo_pdf}
                END

                ${ya_existe}=    Run Keyword And Return Status
                ...    File Should Exist    ${archivo_salida}

                IF    ${ya_existe}
                    Log    \nOmitido (ya existe): ${archivo_salida}    console=True
                    ${omitidos}=    Evaluate    ${omitidos} + 1
                ELSE
                    Log    \n***Convirtiendo ${archivo_entrada}***    console=True
                    ${resultado}=    Run Process
                    ...    ${python}
                    ...    ${CONVERTER}
                    ...    @{argumentos}
                    ...    stdout=PIPE
                    ...    stderr=PIPE

                    Should Be Equal As Integers
                    ...    ${resultado.rc}
                    ...    0
                    ...    msg=Error convirtiendo ${archivo}: ${resultado.stderr}

                    Log    \nGenerado: ${archivo_salida}    console=True
                    ${generados}=    Evaluate    ${generados} + 1
                END
            END
        END
        Log To Console    \nConversión finalizada. Generados: ${generados}. Omitidos: ${omitidos}.
    ELSE
        Log    \nNo existe la carpeta de archivos TXT; se omite la conversión: ${INPUT_DIR}    console=True
    END
