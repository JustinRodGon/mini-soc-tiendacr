import markdown, sys, pathlib
src = pathlib.Path("docs/informe.md").read_text()
body = markdown.markdown(src, extensions=["tables","fenced_code","toc","sane_lists"])
css = """
@page { size: A4; margin: 2cm 2cm; }
* { box-sizing: border-box; }
body { font-family: 'Liberation Serif','DejaVu Serif',Georgia,serif; font-size: 10.5pt; line-height: 1.4; color:#1a1a1a; max-width:none; }
h1 { font-size: 20pt; border-bottom:3px solid #1f4e79; padding-bottom:6px; color:#1f4e79; }
h2:first-of-type { page-break-before: always; }
h2 { font-size: 14pt; color:#1f4e79; border-bottom:1px solid #bcd; padding-bottom:3px; margin-top:22px; page-break-after:avoid; }
h3 { font-size: 12pt; color:#2a2a2a; margin-top:16px; page-break-after:avoid; }
h4 { font-size: 10.5pt; color:#444; page-break-after:avoid; }
table { border-collapse: collapse; width:100%; margin:10px 0; font-size:8.8pt; page-break-inside:avoid; }
th,td { border:1px solid #9bb; padding:4px 6px; text-align:left; vertical-align:top; }
th { background:#1f4e79; color:#fff; font-family:'Liberation Sans',sans-serif; }
tr:nth-child(even) td { background:#eef3f8; }
code { font-family:'Liberation Mono','DejaVu Sans Mono',monospace; font-size:8.5pt; background:#f0f0f0; padding:1px 3px; border-radius:3px; }
pre { background:#f6f8fa; border:1px solid #ddd; border-radius:5px; padding:10px; overflow:auto; page-break-inside:avoid; font-size:8pt; line-height:1.3; }
pre code { background:none; padding:0; }
blockquote { border-left:4px solid #e0a800; background:#fffbe6; margin:10px 0; padding:8px 14px; color:#604; font-size:9.5pt; }
blockquote p { margin:3px 0; }
a { color:#1f4e79; text-decoration:none; }
strong { color:#111; }
hr { border:none; border-top:1px solid #ccd; margin:18px 0; }
img { max-width:100%; height:auto; border:1px solid #bcd; margin:8px 0; page-break-inside:avoid; }
ul,ol { margin:6px 0 6px 0; }
"""
html = f"""<!doctype html><html lang="es"><head><meta charset="utf-8">
<title>Informe Mini SOC TiendaCR</title><style>{css}</style></head><body>{body}</body></html>"""
pathlib.Path("docs/informe.html").write_text(html)
print("html", len(html), "bytes")
