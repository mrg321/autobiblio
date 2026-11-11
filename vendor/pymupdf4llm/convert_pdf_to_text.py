#!/usr/bin/env python3
"""Convierte un PDF a texto localmente usando PyMuPDF4LLM."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TITULO_MINIMO = 20
TITULO_MAXIMO = 130
TITULO_MINIMO_PALABRAS = 4

def limpiar_lineas_en_blanco(texto: str) -> str:
    # Normalizar saltos de línea
    texto = texto.replace("\r\n", "\n").replace("\r", "\n")

    # Elimina espacios y tabuladores al final de cada línea
    texto = re.sub(r"[ \t]+$", "", texto, flags=re.MULTILINE)

    # Reduce dos o más líneas vacías consecutivas a una sola
    texto = re.sub(r"\n[ \t]*\n(?:[ \t]*\n)+", "\n\n", texto)

    # Elimina líneas vacías al principio y al final
    return texto.strip() + "\n"


def _texto_bloque_en_negrita(bloque: str) -> str | None:
    lineas = [linea.strip() for linea in bloque.splitlines() if linea.strip()]
    if not lineas or not all(
        re.fullmatch(r"(?:\*\*[^*\n]+\*\*)+", linea)
        for linea in lineas
    ):
        return None

    titulo = " ".join(
        re.sub(r"\*\*([^*]+)\*\*", r"\1", linea)
        for linea in lineas
    )
    return re.sub(
        r"\s*[—–-]\s*P\d+(?:\s*(?:A|Y)\s*\d+)*\s*$",
        "",
        titulo,
        flags=re.IGNORECASE,
    ).strip()


def convertir_titulos_en_encabezados(texto: str) -> str:
    bloques = re.split(r"(\n[ \t]*\n)", texto)
    resultado: list[str] = []
    indice = 0

    while indice < len(bloques):
        bloque = bloques[indice]
        separador = bloques[indice + 1] if indice + 1 < len(bloques) else ""
        titulo = _texto_bloque_en_negrita(bloque)

        if titulo is not None:
            siguiente = indice + 2
            while siguiente < len(bloques):
                siguiente_titulo = _texto_bloque_en_negrita(bloques[siguiente])
                if siguiente_titulo is None:
                    break
                inicio = siguiente_titulo.lstrip("“‘\"«([{")
                if not inicio or not inicio[0].islower():
                    break

                titulo = f"{titulo} {siguiente_titulo}"
                indice = siguiente
                separador = (
                    bloques[indice + 1] if indice + 1 < len(bloques) else ""
                )
                siguiente = indice + 2
            
            # Verifica si el título cumple con los criterios de longitud y número de palabras
            palabras = re.findall(r"\w+", titulo, flags=re.UNICODE)
            if (
                TITULO_MINIMO <= len(titulo) <= TITULO_MAXIMO
                and len(palabras) >= TITULO_MINIMO_PALABRAS
                and not titulo.endswith(".")
            ):
                resultado.append(f"## {titulo}{separador}")
            else:
                resultado.append(bloque + separador)
        else:
            resultado.append(bloque + separador)

        indice += 2

    return "".join(resultado)

def custom_headers(span, page=None):
    # 1. Obtener el texto del span y limpiarlo de espacios sobrantes
    texto = span.get("text", "").strip()
    
    if not texto:
        return ""
        
    # 2. Definir tamaño de fuente y propiedades de estilo
    size = span.get("size", 0)
    flags = span.get("flags", 0)
    font_name = span.get("font", "")
    
    # Detectar si el texto está en negrita (bit 16 en PyMuPDF o nombre de fuente 'Bold')
    es_negrita = bool(flags & 16) or "Bold" in font_name
    
    # --- REGLAS DE FILTRADO ---
    
    # A. Rango de tamaño de fuente (opcional)
    # if not (12 <= size <= 64):
    #     return ""  
        
    # B. Número mínimo de palabras
    # FLEXIBILIDAD: Si es un título en negrita, permitimos que tenga menos palabras (ej. mínimo 1 o 2)
    # para no descartar líneas como "ALTA JOYERÍA" o "VICTORIA LUENGO".
    palabras = texto.split()
    min_palabras_requerido = 1 if es_negrita else TITULO_MINIMO_PALABRAS
    
    if len(palabras) < min_palabras_requerido:
        return ""
        
    # C. Caracteres prohibidos al inicio o al final
    caracteres_inicio_prohibidos = ("-", ".", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
    caracteres_fin_prohibidos = (",", ".", ";")
    
    if texto.startswith(caracteres_inicio_prohibidos) or texto.endswith(caracteres_fin_prohibidos):
        return ""

    # D. Si el primer carácter es una letra, debe ser obligatoriamente mayúscula
    primer_caracter = texto[0]
    if primer_caracter.isalpha() and not primer_caracter.isupper():
        return ""  # Se descarta si empieza con minúscula
    
    # --- ASIGNACIÓN DE NIVEL DE ENCABEZADO SEGÚN TAMAÑO O ESTILO ---
    if size > 16 or (es_negrita and size > 14):
        return "# "
    elif size > 12 or (es_negrita and size >= 11):
        return "## "
        
    return ""

def convert_pdf(input_path: Path, output_path: Path) -> int:
    try:
        import pymupdf4llm
    except ImportError as exc:
        print(
            "No se encuentra pymupdf4llm. Instala las dependencias con:\n"
            "  python -m pip install -r requirements.txt",
            file=sys.stderr,
        )
        raise SystemExit(2) from exc

    if not input_path.is_file():
        print(f"No existe el PDF de entrada: {input_path}", file=sys.stderr)
        return 2
    if input_path.suffix.lower() != ".pdf":
        print(f"El archivo no tiene extensión .pdf: {input_path}", file=sys.stderr)
        return 2

    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        #headers = pymupdf4llm.IdentifyHeaders(str(input_path), max_levels=3)

        # Reconstruye el orden de lectura y devuelve texto con estructura Markdown.
        # Se guarda en .txt para que sea fácil de consumir como texto.
        text = pymupdf4llm.to_markdown(
            str(input_path),
            #hdr_info=custom_headers,
            header=False,
            footer=False,
            pages=None,
            ignore_images=False,
            write_images=False,
            embed_images=False,
            force_text=True,
            page_chunks=False,
            page_separators=False,
            ignore_code=False,
            use_ocr=False,
            show_progress=True,
            strategy="blocks",
        )
        if not isinstance(text, str):
            text = str(text)
        text = convertir_titulos_en_encabezados(text)
        text = limpiar_lineas_en_blanco(text)
        output_path.write_text(text, encoding="utf-8")
        
    except Exception as exc:
        print(f"Error convirtiendo '{input_path}': {exc}", file=sys.stderr)
        return 1

    print(f"OK: {input_path.name} -> {output_path} ({len(text):,} caracteres)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convierte un PDF a texto usando PyMuPDF4LLM."
    )
    parser.add_argument(
        "--input",
        type=Path,
        help="PDF de entrada",
        default=Path(
            "results/decrypted/20261108T142801358696_el-mundo-ed-nacional-8-11-2026.pdf"
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="TXT de salida",
        default=Path(
            "results/txt/20261108T142801358696_el-mundo-ed-nacional-8-11-2026.txt"
        ),
    )
    args = parser.parse_args()
    return convert_pdf(args.input.resolve(), args.output.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
