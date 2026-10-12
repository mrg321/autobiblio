*** Settings ***
Documentation    Robot para comprobar disponibilidad y solicitar préstamo de prensa en eBiblio Madrid.
Library          Browser
Library          DateTime
Resource         credentials.resource

*** Variables ***
${URL_LOGIN}        https://madrid.ebiblio.es/
${PERIODICO}        El País, edición Madrid

*** Test Cases ***
Login y Prestar Periódico
    # Abrir navegador en modo segundo plano (headless) o no
    New Browser    browser=chromium    headless=False
    New Page       ${URL_LOGIN}

    # Iniciar sesión
    Click          text="Mi Cuenta"
    Fill Text      input[name="login"]    ${USUARIO}
    Fill Text      input[name="password"]    ${PASSWORD}
    Click          button:has-text("Conectarse")

    # Esperar a que el login procese la sesión
    Wait For Elements State    text="Catálogo"    visible    timeout=10s

    # Extraer el catálogo
    Click          text="Catálogo"

    # Esperar a que se cargue la sección de periódicos
    Wait For Elements State    text="Periódicos"    visible    timeout=10s

    # Hacer clic en la sección de periódicos
    Click          text="Periódicos"

    # Obtener fecha actual
    ${fecha_actual}=    Get Current Date    result_format=%d/%m/%Y

    # Componer nombre del periódico para buscarlo
    ${periodico_buscado}=    Set Variable    ${PERIODICO} - ${fecha_actual}

    # Esperar a que aparezca el periódico específico en la lista
    Wait For Elements State    role=link[name="${periodico_buscado}"]   visible    timeout=4 hours

    # Pulsar en el periódico específico
    Click          role=link[name="${periodico_buscado}"]

    # Esperar a que se cargue la página del periódico
    Wait For Elements State    role=heading[name="${periodico_buscado}"]    visible    timeout=10s
    
    # Verificar disponibilidad del botón de préstamo
    ${is_available}=    Run Keyword And Return Status    
    ...                 Wait For Elements State    button:has-text("Prestar")    visible    timeout=5s

    IF    ${is_available}
        Click    button:has-text("Prestar")
        Wait For Elements State    text="Confirmar el préstamo"    visible    timeout=10s
        Click    text="Confirmar el préstamo"
        Wait For Elements State    text="Tu préstamo expira en"    visible    timeout=10s
        Log      ¡Préstamo realizado con éxito!    console=True
    ELSE
        # Verificar disponibilidad del botón de Reserva
        ${is_reservable}=    Run Keyword And Return Status
        ...                 Wait For Elements State    button:has-text("Reservar")    visible    timeout=5s
        IF    ${is_reservable}
            Click    button:has-text("Reservar")
            Wait For Elements State    text="Confirmación de la reserva"    visible    timeout=10s
            Log      ¡Reserva realizada con éxito!    console=True
        ELSE
            Log      El periódico no está disponible ni es reservable.    console=True
        END
    END

    Close Browser
