#!/usr/bin/env bash
# Genera docs/P1_Apellido1_Apellido2.pdf desde docs/informe.md (Markdown -> HTML -> PDF con Chrome).
set -euo pipefail; cd "$(dirname "$0")/.."
python3 -m venv /tmp/mkpdf-venv 2>/dev/null || true
/tmp/mkpdf-venv/bin/pip install -q markdown
/tmp/mkpdf-venv/bin/python docs/generar-pdf.py
google-chrome --headless=new --no-sandbox --disable-gpu --no-pdf-header-footer \
  --print-to-pdf=docs/P1_Apellido1_Apellido2.pdf "file://$PWD/docs/informe.html"
echo "PDF: docs/P1_Apellido1_Apellido2.pdf"
