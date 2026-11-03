#!/usr/bin/env python3
"""Convierte un PDF a texto localmente usando PyMuPDF4LLM."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

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

            palabras = re.findall(r"\w+", titulo, flags=re.UNICODE)
            if (
                20 <= len(titulo) <= 130
                and len(palabras) >= 3
                and not titulo.endswith(".")
            ):
                resultado.append(f"## {titulo}{separador}")
            else:
                resultado.append(bloque + separador)
        else:
            resultado.append(bloque + separador)

        indice += 2

    return "".join(resultado)


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
        # Reconstruye el orden de lectura y devuelve texto con estructura Markdown.
        # Se guarda en .txt para que sea fácil de consumir como texto.
        text = pymupdf4llm.to_markdown(
            str(input_path),
            hdr_info=False,
            header=True,
            footer=True,
            pages=None,
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
    parser.add_argument("--input", required=True, type=Path, help="PDF de entrada")
    parser.add_argument("--output", required=True, type=Path, help="TXT de salida")
    args = parser.parse_args()
    return convert_pdf(args.input.resolve(), args.output.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
