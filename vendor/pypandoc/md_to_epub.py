
#!/usr/bin/env python3
"""
Convierte archivos Markdown o TXT a EPUB mediante pypandoc.

Requisitos:
    - Python 3
    - pypandoc instalado
    - Pandoc instalado y accesible desde PATH

Ejemplos:
    python md_to_epub.py noticia.md
    python md_to_epub.py noticia.txt -o noticia.epub
    python md_to_epub.py noticia.md --title "El País"
    python md_to_epub.py noticia.md --toc --author "Prensa"
"""

import argparse
import sys
from pathlib import Path


def convertir_a_epub(
    archivo_entrada,
    archivo_salida=None,
    titulo=None,
    autor=None,
    indice=True
):
    entrada = Path(archivo_entrada).resolve()

    # Comprobar archivo de entrada
    if not entrada.is_file():
        raise FileNotFoundError(
            f"No existe el archivo: {entrada}"
        )

    try:
        import pypandoc
    except ImportError as exc:
        raise RuntimeError(
            "No se encuentra pypandoc. "
            "Instala las dependencias con: python -m pip install -r requirements.txt"
        ) from exc

    # Nombre del epub de salida
    if archivo_salida:
        salida = Path(archivo_salida).resolve()
    else:
        salida = entrada.with_suffix(".epub")

    salida.parent.mkdir(parents=True, exist_ok=True)

    # Metadatos
    if not titulo:
        titulo = entrada.stem

    argumentos = [
        "--wrap=none",
        "--metadata", f"title={titulo}",
        "--metadata", "lang=es",
    ]

    if autor:
        argumentos.extend(["--metadata", f"author={autor}"])

    if indice:
        argumentos.append("--toc")
        argumentos.append("--toc-depth=2")

    pypandoc.convert_file(
        str(entrada),
        to="epub",
        format="markdown-blank_before_header",
        outputfile=str(salida),
        extra_args=argumentos,
    )

    if not salida.is_file():
        raise RuntimeError("pypandoc no ha generado el archivo epub.")

    return salida


def main():
    parser = argparse.ArgumentParser(
        description="Convierte Markdown/TXT a epub para Kindle."
    )

    parser.add_argument(
        "entrada",
        help="Archivo TXT o Markdown de entrada"
    )

    parser.add_argument(
        "-o", "--output",
        help="Archivo epub de salida"
    )

    parser.add_argument(
        "--title",
        help="Título del libro"
    )

    parser.add_argument(
        "--author",
        help="Autor del libro"
    )

    parser.add_argument(
        "--toc",
        action="store_true",
        default=True,
        help="Generar índice de contenidos (por defecto)"
    )
    parser.add_argument(
        "--no-toc",
        dest="toc",
        action="store_false",
        help="No generar índice de contenidos"
    )

    args = parser.parse_args()

    try:
        salida = convertir_a_epub(
            archivo_entrada=args.entrada,
            archivo_salida=args.output,
            titulo=args.title,
            autor=args.author,
            indice=args.toc
        )

        print(f"epub generado correctamente: {salida}")

    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
