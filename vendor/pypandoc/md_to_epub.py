
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
import tempfile
from pathlib import Path


def convertir_a_epub(
    archivo_entrada,
    archivo_salida=None,
    titulo=None,
    autor=None,
    indice=True,
    archivo_portada_pdf=None,
):
    entrada = Path(archivo_entrada).resolve()
    pdf_portada = (
        Path(archivo_portada_pdf).resolve() if archivo_portada_pdf else None
    )

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

    with tempfile.TemporaryDirectory() as directorio_temporal:
        if pdf_portada:
            if not pdf_portada.is_file():
                raise FileNotFoundError(
                    f"No existe el PDF para la portada: {pdf_portada}"
                )

            try:
                import pymupdf
            except ImportError as exc:
                raise RuntimeError(
                    "No se encuentra PyMuPDF, necesario para generar la portada."
                ) from exc

            with pymupdf.open(pdf_portada) as documento:
                if len(documento) == 0:
                    raise ValueError(f"El PDF no contiene páginas: {pdf_portada}")
                imagen_portada = Path(directorio_temporal) / "portada.png"
                documento[0].get_pixmap(
                    matrix=pymupdf.Matrix(2, 2),
                    alpha=False,
                ).save(str(imagen_portada))

            argumentos.extend(["--epub-cover-image", str(imagen_portada)])

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
        "--cover-pdf",
        help="PDF de origen para generar la portada EPUB con su primera página"
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
            indice=args.toc,
            archivo_portada_pdf=args.cover_pdf,
        )

        print(f"epub generado correctamente: {salida}")

    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
