import os
import json
import sys
import time
import argparse
from typing import List, Optional
from pydantic import BaseModel, Field
from google import genai
from google.genai import types
from google.genai.errors import APIError

# ==========================================
# 1. Definición de Esquemas Pydantic
# ==========================================
class ItemIndice(BaseModel):
    id_articulo: int = Field(description="Identificador numérico secuencial del artículo.")
    titulo: str = Field(description="Título del artículo.")
    seccion: str = Field(description="Sección del diario (ej. Internacional, Economía, Local).")
    linea_inicio: int = Field(description="Número de línea aproximado donde comienza el artículo en el archivo original.")
    linea_fin: int = Field(description="Número de línea aproximado donde termina el artículo en el archivo original.")

class IndiceDiario(BaseModel):
    articulos: List[ItemIndice] = Field(description="Lista completa de todos los artículos identificados en el diario.")

class ArticuloDetallado(BaseModel):
    titulo: str
    seccion: str
    autor: Optional[str] = Field(default=None, description="Autor del artículo si se menciona.")
    resumen: str = Field(description="Breve resumen del contenido.")
    cuerpo_limpio: str = Field(description="Texto completo y limpio del artículo.")


# ==========================================
# 2. Funciones Principales
# ==========================================
def generar_indice_diario(client: genai.Client, texto_completo: str, model: str) -> List[dict]:
    """Paso 1: Analiza el diario entero para extraer el índice de artículos y sus rangos de líneas."""
    print("[-] Paso 1: Generando índice de artículos del diario completo...")
    
    lineas = texto_completo.splitlines()
    texto_con_lineas = "\n".join([f"Línea {i+1}: {linea}" for i, linea in enumerate(lineas)])
    
    prompt = f"""
    Eres un analista documental experto. Analiza el siguiente texto completo de un diario (que incluye los números de línea al principio de cada una).
    Tu objetivo es listar TODOS los artículos informativos o de opinión presentes en el texto y mapear exactamente 
    en qué número de línea empiezan y en qué número de línea terminan.

    TEXTO DEL DIARIO:
    {texto_con_lineas}
    """

    try:
        response = client.models.generate_content(
            model=model,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=IndiceDiario,
                temperature=0.1,
            ),
        )
        resultado = json.loads(response.text)
        return resultado.get("articulos", [])
    except APIError as e:
        print(f"[!] Error de API en el Paso 1: {e}", file=sys.stderr)
        return []

def procesar_articulo_individual(client: genai.Client, texto_fragmento: str, model: str) -> dict:
    """Paso 2: Extrae y estructura el contenido detallado de un fragmento específico."""
    prompt = f"""
    A partir del siguiente fragmento de texto correspondiente a un único artículo, 
    extrae su información estructurada según el esquema requerido. Limpia posibles ruidos de maquetación o cabeceras repetidas.

    FRAGMENTO:
    {texto_fragmento}
    """
    
    try:
        response = client.models.generate_content(
            model=model,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=ArticuloDetallado,
                temperature=0.2,
            ),
        )
        return json.loads(response.text)
    except APIError as e:
        print(f"[!] Error al procesar artículo individual: {e}", file=sys.stderr)
        return None


# ==========================================
# 3. Flujo Principal de Ejecución y Argumentos
# ==========================================
def main():
    parser = argparse.ArgumentParser(description="Procesador de diarios en dos pasos con Gemini.")
    parser.add_argument("archivo", type=str, help="Ruta al archivo de texto del diario.")
    parser.add_argument("--api-key", "-k", type=str, default=None, help="Clave de API de Gemini (opcional si está en variable de entorno).")
    parser.add_argument("--model", type=str, default="gemini-3.8-flash", help="Modelo de Gemini que se utilizará.")
    parser.add_argument("--output-dir", type=str, default="results/cleaned_articles", help="Directorio donde guardar los artículos.")
    
    args = parser.parse_args()
    
    output_dir = args.output_dir
    os.makedirs(output_dir, exist_ok=True)

    try:
        with open(args.archivo, 'r', encoding='utf-8') as f:
            contenido_total = f.read()
    except Exception as e:
        print(json.dumps({"estado": "error", "mensaje": f"No se pudo leer el archivo: {str(e)}"}))
        sys.exit(1)

    lineas_archivo = contenido_total.splitlines()

    # Inicializar cliente de Gemini pasando la API key si viene por argumento
    if args.api_key:
        client = genai.Client(api_key=args.api_key)
    else:
        client = genai.Client()  # Recurre por defecto a la variable de entorno GEMINI_API_KEY

    # PASO 1: Obtener el índice de artículos
    articulos_indice = generar_indice_diario(client, contenido_total, args.model)
    
    if not articulos_indice:
        print(json.dumps({"estado": "error", "mensaje": "No se pudieron extraer artículos en el índice."}))
        sys.exit(1)

    print(f"[+] Índice generado con éxito. Se encontraron {len(articulos_indice)} artículos.")
    
    # PASO 2: Procesar y guardar cada artículo de forma independiente
    exitos = 0
    for idx, item in enumerate(articulos_indice):
        inicio = max(0, item.get("linea_inicio", 1) - 1)
        fin = min(len(lineas_archivo), item.get("linea_fin", len(lineas_archivo)))
        
        fragmento_texto = "\n".join(lineas_archivo[inicio:fin])
        
        if not fragmento_texto.strip():
            continue

        print(f"[-] Procesando ({idx+1}/{len(articulos_indice)}): {item.get('titulo')}...")
        
        datos_detallados = procesar_articulo_individual(client, fragmento_texto, args.model)
        
        if datos_detallados:
            nombre_archivo = f"articulo_{idx+1:03d}.json"
            ruta_salida = os.path.join(output_dir, nombre_archivo)
            
            with open(ruta_salida, 'w', encoding='utf-8') as out_f:
                json.dump(datos_detallados, out_f, ensure_ascii=False, indent=2)
            exitos += 1
            
        time.sleep(1)

    print(f"\n[✓] Proceso finalizado. {exitos} de {len(articulos_indice)} artículos guardados en la carpeta '{output_dir}/'.")

if __name__ == "__main__":
    main()