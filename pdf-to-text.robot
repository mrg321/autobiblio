*** Settings ***
Documentation     Convierte todos los PDF de results/decrypted a TXT en results/txt.
Library           OperatingSystem
Library           Process

*** Variables ***
${ROOT_DIR}       ${CURDIR}
${INPUT_DIR}      ${ROOT_DIR}${/}results${/}decrypted
${OUTPUT_FOLDER}     ${ROOT_DIR}${/}results${/}txt
${CONVERTER}      ${ROOT_DIR}${/}vendor${/}pymupdf4llm${/}convert_pdf_to_text.py

*** Test Cases ***
Convertir todos los PDF a texto
    [Documentation]    Procesa cada PDF de entrada y crea un TXT con el mismo nombre base.
    ${input_dir_exists}=    Run Keyword And Return Status
    ...    Directory Should Exist    ${INPUT_DIR}
    IF    ${input_dir_exists}
        ${python}=    Evaluate    sys.executable    modules=sys
        File Should Exist         ${CONVERTER}
        Create Directory          ${OUTPUT_FOLDER}
        @{pdf_files}=    List Files In Directory    ${INPUT_DIR}    pattern=*.pdf    absolute=True
        Should Not Be Empty    ${pdf_files}    No se han encontrado archivos PDF en ${INPUT_DIR}

        FOR    ${pdf}    IN    @{pdf_files}
            ${nombre}=    Evaluate    pathlib.Path($pdf).stem    modules=pathlib
            ${salida}=    Set Variable    ${OUTPUT_FOLDER}${/}${nombre}.txt
            ${salida_existe}=    Run Keyword And Return Status    File Should Exist    ${salida}
            IF    ${salida_existe}
                Log    Omitiendo ${pdf}: ya existe ${salida}
            ELSE
                Log    Convirtiendo ${pdf} -> ${salida}
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
    ELSE
        Log    No existe la carpeta de archivos descifrados; se omite la conversión: ${INPUT_DIR}    console=True
    END
