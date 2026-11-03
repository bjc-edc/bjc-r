#!/usr/bin/env python3
"""Regenerate img/6-computers/logic-gates-quiz-{a,b}[.es].svg.

    python3 utilities/images/build-logic-gate-svgs.py

These replace the Graphviz-rendered PNGs of the same name. Every coordinate
was measured off those PNGs, so the SVGs are drop-in replacements at the same
intrinsic size (116x308) and the same layout; only the rendering is now vector
text and vector strokes instead of a 116px-wide bitmap.

Circuit "a" is choice II on the unit 6 quiz and reports false; circuit "b" is
choice I and reports true. Edit LAYOUTS/LANGS here and re-run rather than
hand-editing the SVGs, so the <desc> prose can't drift from the drawing.
"""
import html
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

W, H = 116, 308
R = 15            # input-circle radius
FS_IN = 12        # input letter size
FS_GATE = 13      # gate label size
FS_OUT = 12       # output label size

FONT = "ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', monospace"

INK = '#1A1A1A'
PAPER = '#FFFFFF'


def baseline(cy, fs):
    """Y coordinate that visually centres text of size `fs` on `cy`."""
    return round(cy + fs * 0.36, 2)


# Circuit "a" is choice II on the quiz; circuit "b" is choice I.
LAYOUTS = {
    'a': {
        'circles': [(62.5, 15), (100, 15), (15, 155), (52.5, 155)],
        # (x0, y0, x1, y1, gate-key)
        'boxes': [(52, 50, 111, 77, 'or'), (52, 95, 111, 122, 'not'),
                  (4, 190, 63, 217, 'or'), (25, 238, 90, 265, 'and')],
        'arrows': [(62.5, 30, 62.5, 50), (100, 30, 100, 50),
                   (81.5, 77, 81.5, 95), (81.5, 122, 81.5, 238),
                   (15, 170, 15, 190), (52.5, 170, 52.5, 190),
                   (33.5, 217, 33.5, 238), (57.5, 265, 57.5, 286)],
    },
    'b': {
        'circles': [(15, 15), (52.5, 15), (62.5, 155), (100, 155)],
        'boxes': [(4, 50, 63, 77, 'and'), (4, 95, 63, 122, 'not'),
                  (52, 190, 111, 217, 'and'), (25, 238, 90, 265, 'or')],
        'arrows': [(15, 30, 15, 50), (52.5, 30, 52.5, 50),
                   (33.5, 77, 33.5, 95), (33.5, 122, 33.5, 238),
                   (62.5, 170, 62.5, 190), (100, 170, 100, 190),
                   (81.5, 217, 81.5, 238), (57.5, 265, 57.5, 286)],
    },
}

# Inputs are T/F in both languages (the Spanish page explains that T means
# "verdadero" and F means "falso"), so only the gate and output labels differ.
LANGS = {
    'en': {
        'lang': 'en',
        'gates': {'or': 'OR', 'and': 'AND', 'not': 'NOT'},
        'output': 'output',
        'title': {
            'a': 'Logic circuit II: (T OR F) AND NOT (T OR F)',
            'b': 'Logic circuit I: NOT (T AND F) OR (T AND F)',
        },
        'desc': {
            'a': 'A circuit diagram read from top to bottom. Inputs T and F feed an OR '
                 'gate, and that OR gate feeds a NOT gate. Separately, a second pair of '
                 'inputs T and F feed a second OR gate. The NOT gate and the second OR '
                 'gate are the two inputs to an AND gate, and the AND gate produces the '
                 'output of the circuit.',
            'b': 'A circuit diagram read from top to bottom. Inputs T and F feed an AND '
                 'gate, and that AND gate feeds a NOT gate. Separately, a second pair of '
                 'inputs T and F feed a second AND gate. The NOT gate and the second AND '
                 'gate are the two inputs to an OR gate, and the OR gate produces the '
                 'output of the circuit.',
        },
    },
    'es': {
        'lang': 'es',
        'gates': {'or': 'O', 'and': 'Y', 'not': 'NO'},
        'output': 'Salida',
        'title': {
            'a': 'Circuito lógico II: (T O F) Y NO (T O F)',
            'b': 'Circuito lógico I: NO (T Y F) O (T Y F)',
        },
        'desc': {
            'a': 'Un diagrama de circuito que se lee de arriba abajo. Las entradas T y F '
                 'alimentan una compuerta O, y esa compuerta O alimenta una compuerta NO. '
                 'Por separado, un segundo par de entradas T y F alimentan una segunda '
                 'compuerta O. La compuerta NO y la segunda compuerta O son las dos '
                 'entradas de una compuerta Y, y la compuerta Y produce la salida del '
                 'circuito.',
            'b': 'Un diagrama de circuito que se lee de arriba abajo. Las entradas T y F '
                 'alimentan una compuerta Y, y esa compuerta Y alimenta una compuerta NO. '
                 'Por separado, un segundo par de entradas T y F alimentan una segunda '
                 'compuerta Y. La compuerta NO y la segunda compuerta Y son las dos '
                 'entradas de una compuerta O, y la compuerta O produce la salida del '
                 'circuito.',
        },
    },
}

INPUT_LETTERS = ['T', 'F', 'T', 'F']


def build(variant, lang_key):
    lang = LANGS[lang_key]
    layout = LAYOUTS[variant]
    slug = f'lgq-{variant}' + ('' if lang_key == 'en' else f'-{lang_key}')

    out = []
    # These files are only ever referenced with <img src>, and an SVG in an
    # <img> is an isolated document: it inherits no `color` from the page and
    # forced-colors state is not propagated into it. So the palette is explicit
    # and the diagram paints its own opaque background -- otherwise it would be
    # black-on-transparent, i.e. invisible in High Contrast Mode and in dark
    # reader modes. aria-labelledby names it and aria-describedby describes it;
    # both on labelledby would run the two together into one accessible name.
    out.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
        f'width="{W}" height="{H}" role="img" '
        f'aria-labelledby="{slug}-title" aria-describedby="{slug}-desc" '
        f'lang="{lang["lang"]}">'
    )
    out.append(f'  <title id="{slug}-title">{html.escape(lang["title"][variant])}</title>')
    out.append(f'  <desc id="{slug}-desc">{html.escape(lang["desc"][variant])}</desc>')
    out.append('  <style>')
    out.append(f'    .bg {{ fill: {PAPER}; }}')
    out.append(f'    .shape {{ fill: none; stroke: {INK}; stroke-width: 1.2; }}')
    out.append(f'    text {{ fill: {INK}; font-family: {FONT}; text-anchor: middle; }}')
    out.append('  </style>')
    out.append('  <defs>')
    out.append(
        f'    <marker id="{slug}-head" viewBox="0 0 8 8" refX="7.5" refY="4" '
        f'markerWidth="7" markerHeight="7" markerUnits="userSpaceOnUse" orient="auto">'
    )
    out.append(f'      <path d="M0 0 L8 4 L0 8 Z" fill="{INK}"/>')
    out.append('    </marker>')
    out.append('  </defs>')
    out.append(f'  <rect class="bg" width="{W}" height="{H}"/>')

    out.append('  <g class="shape">')
    for cx, cy in layout['circles']:
        out.append(f'    <circle cx="{cx}" cy="{cy}" r="{R}"/>')
    for x0, y0, x1, y1, _ in layout['boxes']:
        out.append(f'    <rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}"/>')
    for x0, y0, x1, y1 in layout['arrows']:
        out.append(
            f'    <line x1="{x0}" y1="{y0}" x2="{x1}" y2="{y1}" '
            f'marker-end="url(#{slug}-head)"/>'
        )
    out.append('  </g>')

    for (cx, cy), letter in zip(layout['circles'], INPUT_LETTERS):
        out.append(f'  <text x="{cx}" y="{baseline(cy, FS_IN)}" font-size="{FS_IN}">{letter}</text>')
    for x0, y0, x1, y1, key in layout['boxes']:
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        label = html.escape(lang['gates'][key])
        out.append(f'  <text x="{cx}" y="{baseline(cy, FS_GATE)}" font-size="{FS_GATE}">{label}</text>')
    out.append(
        f'  <text x="57.5" y="{baseline(297, FS_OUT)}" font-size="{FS_OUT}">'
        f'{html.escape(lang["output"])}</text>'
    )
    out.append('</svg>')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    for variant in ('a', 'b'):
        for lang_key in ('en', 'es'):
            suffix = '' if lang_key == 'en' else '.es'
            path = os.path.join(REPO, 'img', '6-computers',
                                f'logic-gates-quiz-{variant}{suffix}.svg')
            with open(path, 'w', encoding='utf-8') as fh:
                fh.write(build(variant, lang_key))
            print('wrote', os.path.relpath(path, REPO))
