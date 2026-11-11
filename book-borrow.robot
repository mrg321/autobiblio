*** Settings ***
Documentation    Robot para solicitar préstamo de un periódico ya reservado en eBiblio Madrid.
Library          Browser
Library          DateTime
Library          OperatingSystem
Resource         credentials.resource
Test Teardown     Capture Screenshot If Test Failed

*** Variables ***
${URL_LOGIN}        https://madrid.ebiblio.es/
${HEADLESS}         ${True}
${OUTPUT_FOLDER}    ${CURDIR}${/}results${/}downloads
${OFFLINE_DOWNLOAD_LINK}    xpath=//a[normalize-space(.)="Leer sin conexión desde un ordenador (con Thorium Reader)" or
...                         normalize-space(.)="Escuchar sin conexión en un ordenador"]

*** Test Cases ***
Login y Obtener Periódico
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

    # Verificar disponibilidad de libros o audiolibros para descargar
    ${is_available}=    Run Keyword And Return Status    
    ...                 Wait For Elements State    ${OFFLINE_DOWNLOAD_LINK} >> nth=0    visible    timeout=20s
    # Procesar todos los contenidos disponibles para descarga
    IF    ${is_available}
        ${available_count}=    Get Element Count    ${OFFLINE_DOWNLOAD_LINK}
        FOR    ${book_index}    IN RANGE    ${available_count}
            IF    ${book_index} > 0
                Go To    ${URL_LOGIN}my_profile/activity
                Wait For Elements State    ${OFFLINE_DOWNLOAD_LINK} >> nth=${book_index}    visible    timeout=20s
            END
            Descargar Contenido Offline    ${book_index}
        END
    ELSE
        Log    \nNo hay libros ni audiolibros disponibles para descarga.    console=True
    END

    # Verificar disponibilidad del botón de préstamo
    ${is_available}=    Run Keyword And Return Status    
    ...                 Wait For Elements State    role=link[name="Prestar"] >> nth=0     visible    timeout=20s

    # Procesar todos los periódicos disponibles para préstamo
    IF    ${is_available}
        ${available_count}=    Get Element Count    role=link[name="Prestar"]
        FOR    ${book_index}    IN RANGE    ${available_count}
            IF    ${book_index} > 0
                Go To    ${URL_LOGIN}my_profile/activity
                Wait For Elements State    role=link[name="Prestar"]    visible    timeout=20s
            END
            Click    role=link[name="Prestar"] >> nth=0
            Descargar Contenido Offline
        END
    ELSE
        Log    \nNo hay periódicos disponibles para préstamo.    console=True
    END

    Close Browser

*** Keywords ***
Capture Screenshot If Test Failed
    IF    $TEST_STATUS == 'FAIL'
        ${screenshots_dir}=    Set Variable    ${OUTPUT DIR}${/}screenshots
        Create Directory    ${screenshots_dir}
        Take Screenshot    filename=${screenshots_dir}${/}failure.png
    END

Descargar Contenido Offline
    [Arguments]    ${link_index}=0
    ${download_link}=    Set Variable    ${OFFLINE_DOWNLOAD_LINK} >> nth=${link_index}
    Wait For Elements State
    ...    ${download_link}
    ...    visible
    ...    timeout=20s
    ${download_dir}=    Set Variable    ${OUTPUT_FOLDER}
    Create Directory    ${download_dir}
    ${download_timestamp}=    Get Current Date    result_format=%Y%m%dT%H%M%S%f
    ${download_path}=    Set Variable
    ...    ${download_dir}${/}${download_timestamp}_download
    ${download_promise}=    Promise To Wait For Download
    ...    ${download_path}
    ...    download_timeout=5 minutes
    Click    ${download_link}
    ${download}=    Wait For    ${download_promise}
    Should Not Be Empty    ${download}[suggestedFilename]
    ${download_file}=    Set Variable
    ...    ${download_dir}${/}${download_timestamp}_${download}[suggestedFilename]
    Move File    ${download}[saveAs]    ${download_file}
    File Should Exist    ${download_file}
    Log    \n***Archivo descargado: ${download_file}***    console=True
