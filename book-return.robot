*** Settings ***
Documentation    Robot para solicitar devolución de periódicos ya prestados en eBiblio Madrid.
Library          Browser
Library          DateTime
Library          OperatingSystem
Resource         credentials.resource
Test Teardown     Capture Screenshot If Test Failed

*** Variables ***
${URL_LOGIN}        https://madrid.ebiblio.es/
${HEADLESS}         ${True}
${OUTPUT_FOLDER}    ${CURDIR}${/}results${/}downloads

*** Test Cases ***
Login y Devolver Periódico
    # Abrir navegador en modo segundo plano (headless) o no
    New Browser    browser=chromium    headless=${HEADLESS}
    New Context    acceptDownloads=True
    New Page       ${URL_LOGIN}

    # Iniciar sesión
    Click          text="Mi Cuenta"
    Fill Text      input[name="login"]    ${USUARIO}
    Fill Text      input[name="password"]    ${PASSWORD}

    Click          button:has-text("Conectarse")

    # Esperar a que el login procese la sesión
    Wait For Elements State    text="Catálogo"    visible    timeout=20s

    # Abrir préstamos y reservas activos
    New Page         ${URL_LOGIN}my_profile/activity

    # Verificar disponibilidad de libros para devolver
    ${is_available}=    Run Keyword And Return Status
    ...                 Wait For Elements State    role=button[name="Devolver préstamo"] >> nth=0    visible    timeout=20s
    # Procesar todos los periódicos disponibles para devolución
    IF    ${is_available}
        ${available_count}=    Get Element Count    role=button[name="Devolver préstamo"]
        FOR    ${book_index}    IN RANGE    ${available_count}
            ${return_button}=    Set Variable    role=button[name="Devolver préstamo"] >> nth=0
            IF    ${book_index} > 0
                Go To    ${URL_LOGIN}my_profile/activity
                Wait For Elements State    ${return_button}    visible    timeout=20s
            END
            Devolver Libro    ${return_button}
        END
    ELSE
        Log    No hay periódicos disponibles para devolución.    console=True
    END

    Close Browser

*** Keywords ***
Capture Screenshot If Test Failed
    IF    $TEST_STATUS == 'FAIL'
        ${screenshots_dir}=    Set Variable    ${OUTPUT DIR}${/}screenshots
        Create Directory    ${screenshots_dir}
        Take Screenshot    filename=${screenshots_dir}${/}failure.png
    END

Devolver Libro
    [Arguments]    ${return_button}
    Handle Future Dialogs    action=accept
    Click    ${return_button}
    Wait For Elements State    text=Devolución finalizada    visible    timeout=30s
    Log    Periódico devuelto: ${return_button}    console=True
