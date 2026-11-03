*** Settings ***
Documentation     Convierte los Markdown/TXT de results/txt a EPUB en results/epub.
...               Omite los EPUB que ya existen. Ejecutar desde la raíz del proyecto.
Library           OperatingSystem
Library           Process
Library           String

*** Variables ***
${INPUT_DIR}       ${CURDIR}${/}results${/}txt
${OUTPUT_FOLDER}      ${CURDIR}${/}results${/}epub
${CONVERTER}       ${CURDIR}${/}vendor${/}pypandoc${/}md_to_epub.py

*** Test Cases ***
Convertir Todos Los Markdown A EPUB
    [Documentation]    Procesa archivos .md, .markdown y .txt; no regenera EPUB existentes.
    Directory Should Exist    ${INPUT_DIR}
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

            ${ya_existe}=    Run Keyword And Return Status
            ...    File Should Exist    ${archivo_salida}

            IF    ${ya_existe}
                Log    Omitido (ya existe): ${archivo_salida}    INFO
                ${omitidos}=    Evaluate    ${omitidos} + 1
            ELSE
                Log    Convirtiendo: ${archivo_entrada}    INFO
                ${resultado}=    Run Process
                ...    ${python}
                ...    ${CONVERTER}
                ...    ${archivo_entrada}
                ...    -o
                ...    ${archivo_salida}
                ...    --title
                ...    ${nombre_base}
                ...    --toc
                ...    stdout=PIPE
                ...    stderr=PIPE

                Should Be Equal As Integers
                ...    ${resultado.rc}
                ...    0
                ...    msg=Error convirtiendo ${archivo}: ${resultado.stderr}

                Log    Generado: ${archivo_salida}    INFO
                ${generados}=    Evaluate    ${generados} + 1
            END
        END
    END

    Log To Console    \nConversión finalizada. Generados: ${generados}. Omitidos: ${omitidos}.
