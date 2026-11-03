#!/usr/bin/env python3
import argparse
import os
import re
import ssl
import smtplib
from email import encoders
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

def send_book(file_path, sender, password, kindle_email) -> int:
    # Validar que los datos no estén vacíos
    if not sender or not password or not kindle_email:
        print("Error: Faltan credenciales o configuración.")
        print("Asegúrate de pasar los argumentos por línea de comandos o definir las variables de entorno.")
        return 2

    if not os.path.isfile(file_path):
        print(f"Error: El archivo '{file_path}' no existe.")
        return 2

    print(f"Preparando el envío de '{file_path}' a {kindle_email}...")

    # Crear el mensaje multipart
    msg = MIMEMultipart()
    msg['From'] = sender
    msg['To'] = kindle_email
    # El asunto 'convert' le indica a Amazon que convierta el formato (ej. EPUB)
    msg['Subject'] = "convert"

    msg.attach(MIMEText("Libro enviado automáticamente desde script de Python.", 'plain'))

    # Adjuntar el archivo del libro
    try:
        with open(file_path, "rb") as attachment:
            part = MIMEBase("application", "octet-stream")
            part.set_payload(attachment.read())

        encoders.encode_base64(part)
        filename = os.path.basename(file_path)
        filename = re.sub(r"^\d{8}T\d{12}_", "", filename)
        part.add_header("Content-Disposition", f"attachment; filename= {filename}")
        msg.attach(part)
    except OSError as e:
        print(f"Error al leer el archivo adjunto: {e}")
        return 1

    stage = "connecting to Gmail SMTP"
    server = None
    accepted_by_gmail = False
    try:
        server = smtplib.SMTP('smtp.gmail.com', 587, timeout=60)
        stage = "negotiating SMTP capabilities"
        server.ehlo()
        stage = "starting TLS"
        server.starttls(context=ssl.create_default_context())
        stage = "negotiating SMTP capabilities over TLS"
        server.ehlo()
        stage = "authenticating with Gmail"
        server.login(sender, password)
        stage = "submitting the message to Gmail"
        refused = server.sendmail(sender, kindle_email, msg.as_string())
        if refused:
            print(f"Error: El servidor rechazó el envío a {', '.join(refused)}.")
            return 1
        accepted_by_gmail = True
        print("¡Gmail aceptó el mensaje para su entrega a Kindle!")
        return 0
    except (OSError, smtplib.SMTPException) as e:
        print(f"Error while {stage}: {type(e).__name__}: {e}")
        return 1
    finally:
        if server is not None:
            try:
                server.close()
            except OSError as close_error:
                status = "after Gmail accepted the message" if accepted_by_gmail else "after SMTP failed"
                print(f"Warning: Could not close the SMTP connection {status}: {close_error}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Envía libros electrónicos a tu Kindle usando Gmail y variables de entorno.")
    parser.add_argument("file", help="Ruta del archivo del libro (ej. libro.epub)")
    
    # Se enlazan directamente con las variables de entorno del sistema
    parser.add_argument("-s", "--sender", default=os.environ.get("KINDLE_SENDER"), help="Correo de Gmail (o variable KINDLE_SENDER)")
    parser.add_argument("-p", "--password", default=os.environ.get("KINDLE_APP_PASSWORD"), help="Contraseña de aplicación (o variable KINDLE_APP_PASSWORD)")
    parser.add_argument("-k", "--kindle", default=os.environ.get("KINDLE_TARGET_EMAIL"), help="Correo de Kindle (o variable KINDLE_TARGET_EMAIL)")

    args = parser.parse_args()
    raise SystemExit(send_book(args.file, args.sender, args.password, args.kindle))