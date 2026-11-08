*** Settings ***
Documentation    Robot para comprobar disponibilidad y solicitar préstamo de prensa en eBiblio Madrid.
Library          Browser
Library          DateTime
Library          OperatingSystem
Library          String
Resource         credentials.resource
Test Teardown     Capture Screenshot If Test Failed

*** Variables ***
${URL_LOGIN}        https://madrid.ebiblio.es/
@{PERIODICO}        El País, edición Madrid    El Mundo (Ed. Nacional)
${HEADLESS}         ${True}
${DOWNLOAD}         ${False}

*** Test Cases ***
Login y Prestar Periódico
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

    # Navegar al catálogo de periódicos
    Click    text="Catálogo"
    Wait For Elements State    text="Periódicos"    visible    timeout=20s
    Click    text="Periódicos"

    FOR    ${nombre_periodico}    IN    @{PERIODICO}
        ${fecha_actual}=    Get Current Date    result_format=%d/%m/%Y
        @{fecha_partes}=    Split String    ${fecha_actual}    /
        ${dia}=    Convert To Integer    ${fecha_partes}[0]
        ${mes}=    Convert To Integer    ${fecha_partes}[1]
        ${fecha_actual}=    Set Variable    ${dia}/${mes}/${fecha_partes}[2]
        ${periodico_buscado}=    Set Variable    ${nombre_periodico} - ${fecha_actual}
        ${is_listed}=    Run Keyword And Return Status
        ...    Wait For Elements State    role=link[name="${periodico_buscado}"]    visible    timeout=5s

        IF    ${is_listed}
            Click    role=link[name="${periodico_buscado}"]
            Wait For Elements State    role=heading[name="${periodico_buscado}"]    visible    timeout=20s

            ${is_available}=    Run Keyword And Return Status
            ...    Wait For Elements State    button:has-text("Prestar")    visible    timeout=20s

            IF    ${is_available}
                Click    button:has-text("Prestar")
                IF    ${DOWNLOAD}
                    Prestar Y Descargar Libro
                ELSE
                    Wait For Elements State    text="Confirmar el préstamo"    visible    timeout=20s
                    Click    text="Confirmar el préstamo"
                    Wait For Elements State    text="Tu préstamo expira en"    visible    timeout=20s
                    Log    ***Préstamo de ${periodico_buscado} realizado con éxito***    console=True
                END
            ELSE
                ${is_reservable}=    Run Keyword And Return Status
                ...    Wait For Elements State    button:has-text("Reservar")    visible    timeout=5s
                IF    ${is_reservable}
                    Click    button:has-text("Reservar")
                    Wait For Elements State    text="Confirmación de la reserva"    visible    timeout=10s
                    Log    ¡Reserva realizada con éxito!    console=True
                ELSE
                    Log    ${periodico_buscado} no está disponible ni es reservable.    console=True
                END
            END
        ELSE
            Log    No se encontró ${periodico_buscado} en la lista de periódicos.    console=True
        END
        # Volver a la página anterior
        Go Back
        # Volver otra vez a la página de periódicos
        Go Back
    END

    Close Browser

*** Keywords ***
Capture Screenshot If Test Failed
    IF    $TEST_STATUS == 'FAIL'
        ${screenshots_dir}=    Set Variable    ${OUTPUT DIR}${/}screenshots
        Create Directory    ${screenshots_dir}
        Take Screenshot    filename=${screenshots_dir}${/}failure.png
    END

Prestar Y Descargar Libro
    Wait For Elements State    text="Confirmar el préstamo"    visible    timeout=20s
    Click    text="Confirmar el préstamo"
    Wait For Elements State    text="Tu préstamo expira en"    visible    timeout=20s
    Log    ¡Préstamo realizado con éxito!    console=True

    IF    ${DOWNLOAD}
        Wait For Elements State
        ...    role=link[name="Leer sin conexión desde un ordenador (con Thorium Reader)"]
        ...    visible
        ...    timeout=20s
        ${download_dir}=    Set Variable    ${OUTPUT DIR}${/}downloads
        Create Directory    ${download_dir}
        ${download_timestamp}=    Get Current Date    result_format=%Y%m%dT%H%M%S%f
        ${download_path}=    Set Variable
        ...    ${download_dir}${/}${download_timestamp}_download
        ${download_promise}=    Promise To Wait For Download
        ...    ${download_path}
        ...    download_timeout=5 minutes
        Click    role=link[name="Leer sin conexión desde un ordenador (con Thorium Reader)"]
        ${download}=    Wait For    ${download_promise}
        Should Not Be Empty    ${download}[suggestedFilename]
        ${download_file}=    Set Variable
        ...    ${download_dir}${/}${download_timestamp}_${download}[suggestedFilename]
        Move File    ${download}[saveAs]    ${download_file}
        File Should Exist    ${download_file}
        Log    Archivo descargado: ${download_file}    console=True

    END
