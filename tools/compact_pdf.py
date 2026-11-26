"""Kompaktes PDF aus den Folienbildern (export/shots-<lang>), für die Website.
Aufruf: node tools/export.mjs both --shots && python tools/compact_pdf.py"""
import glob, os, sys
from PIL import Image
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for lang in ('de', 'en'):
    files = sorted(glob.glob(os.path.join(root, 'export', f'shots-{lang}', '*.png')))
    if not files: continue
    pages = [Image.open(f).convert('RGB') for f in files]
    out = os.path.join(root, 'export', f'Data-Bash-2026-IBCS-Fabric-Apps-{lang.upper()}-web.pdf')
    pages[0].save(out, save_all=True, append_images=pages[1:], resolution=144, quality=82, optimize=True)
    print(os.path.basename(out), len(pages), 'Seiten', os.path.getsize(out) // 1024, 'KB')
