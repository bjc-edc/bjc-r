#!/usr/bin/env python3
"""Regenerate img/4-internet/redundant-2[.es].svg.

    python3 utilities/images/build-network-graph-svg.py

The drawing replaces img/4-internet/redundant-2.jpg. Node positions and edges
were recovered from that photo by locating the node blobs and then testing
every pair of nodes for a connecting green line, so the graph here is
topologically identical to the one the lab pages have always shown. It also
reproduces the lab's answer key exactly: node 8 is the only degree-6 node, the
only two-node cuts are {6, 8} and {8, 9}, and the only way for eight nodes to
fail with the message still getting through leaves nodes 4 and 8 in the middle.

Each node and connection also carries data-node / data-role / data-from /
data-to attributes, so the topology is machine-readable straight from the
drawing rather than having to be restated somewhere else. This script exists so
that the <desc> text, which repeats the same adjacency in prose, cannot drift
away from the lines that are drawn. Edit POS/EDGES here and re-run rather than
hand-editing the SVG.
"""
import html
import os

W, H = 335, 353

BG = '#000000'
EDGE = '#8DD54B'
NODE = '#C9E9FB'
ENDPOINT = '#F1358C'
NUMBER = '#06263D'
LABEL = '#FFFFFF'

R_NODE = 11
R_END = 12

FONT = "system-ui, -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif"

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

# Recovered pixel positions, keyed by the working letters used during analysis.
POS = {
    'S': (85.5, 23.5), 'R': (85.5, 329.5),
    'a': (73.5, 101.5), 'b': (217.5, 203.5), 'c': (308.5, 155.5),
    'd': (55.5, 185.0), 'e': (42.5, 276.0), 'f': (199.5, 301.5),
    'g': (224.0, 89.0), 'h': (24.0, 101.0), 'i': (145.5, 143.0),
    'j': (129.0, 233.0),
}

# Note: nodes 6 and 10 are NOT directly connected. A straight 6-10 line passes
# within a node radius of node 8, so scanning the original JPEG for green pixels
# between them found the real 6-8 and 8-10 edges instead. Every other edge here
# has no node lying near its chord.
EDGES = [
    ('S', 'g'), ('S', 'h'), ('S', 'i'),
    ('R', 'e'), ('R', 'j'),
    ('a', 'h'), ('a', 'i'),
    ('b', 'f'), ('b', 'i'),
    ('c', 'f'), ('c', 'g'),
    ('d', 'e'), ('d', 'h'), ('d', 'j'),
    ('e', 'j'),
    ('f', 'j'),
    ('g', 'i'),
    ('h', 'j'),
    ('i', 'j'),
]

# The ten relay nodes get visible numbers so that the drawing, the text
# alternative and the answer feedback can all refer to the same node. Numbered
# top to bottom, the order someone reading the picture would find them in.
RELAYS = sorted((k for k in POS if k not in ('S', 'R')),
                key=lambda k: (POS[k][1], POS[k][0]))
NUM = {k: str(n + 1) for n, k in enumerate(RELAYS)}

LANGS = {
    'en': {
        'lang': 'en',
        'sender': 'Sender',
        'receiver': 'Receiver',
        'title': 'A model network with a Sender, a Receiver and ten numbered relay nodes',
        'intro': ('A model network drawn as a graph. Sender and Receiver sit at the top and '
                  'bottom, with {relays} relay nodes numbered 1 to {relays} between them and '
                  '{edges} connections in total. Connections: '),
        'connects': '{node} connects to {list}',
    },
    'es': {
        'lang': 'es',
        'sender': 'Emisor',
        'receiver': 'Receptor',
        'title': 'Un modelo de red con un emisor, un receptor y diez nodos de retransmisión numerados',
        'intro': ('Un modelo de red dibujado como un grafo. El emisor y el receptor están arriba '
                  'y abajo, con {relays} nodos de retransmisión numerados del 1 al {relays} entre '
                  'ellos y {edges} conexiones en total. Conexiones: '),
        'connects': '{node} se conecta con {list}',
    },
}


def names(lang):
    mapping = dict(NUM)
    mapping['S'] = lang['sender']
    mapping['R'] = lang['receiver']
    return mapping


def adjacency():
    """`{node: neighbours}` in Sender, 1..n, Receiver order."""
    adj = {k: set() for k in POS}
    for u, v in EDGES:
        adj[u].add(v)
        adj[v].add(u)
    rank = lambda k: (0 if k == 'S' else 2 if k == 'R' else 1, int(NUM.get(k, 0)))
    return {k: sorted(adj[k], key=rank) for k in POS}


def describe(lang):
    name = names(lang)
    adj = adjacency()
    intro = lang['intro'].format(relays=len(RELAYS), edges=len(EDGES))
    body = '; '.join(
        lang['connects'].format(node=name[k], list=', '.join(name[n] for n in adj[k]))
        for k in ['S'] + RELAYS + ['R']
    )
    return intro + body + '.'


def build(lang):
    name = names(lang)
    out = []
    # aria-labelledby names the graphic and aria-describedby describes it. Both
    # on labelledby would concatenate the whole adjacency list into a single
    # unskippable accessible name.
    out.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
        f'width="{W}" height="{H}" class="netgraph" lang="{lang["lang"]}" role="img" '
        f'aria-labelledby="netgraph-title" aria-describedby="netgraph-desc">'
    )
    out.append(f'  <title id="netgraph-title">{html.escape(lang["title"])}</title>')
    out.append(f'  <desc id="netgraph-desc">{html.escape(describe(lang))}</desc>')
    # Class names are prefixed because this stylesheet becomes part of the
    # page's stylesheet set once network-graph.js inlines the file.
    out.append('  <style>')
    out.append(f'    .ng-bg {{ fill: {BG}; }}')
    out.append(f'    .ng-edge {{ stroke: {EDGE}; stroke-width: 3; stroke-linecap: round; }}')
    out.append(f'    .ng-node {{ fill: {NODE}; }}')
    out.append(f'    .ng-endpoint {{ fill: {ENDPOINT}; }}')
    out.append(f'    .ng-num {{ fill: {NUMBER}; font: 700 13px {FONT}; text-anchor: middle; }}')
    out.append(f'    .ng-label {{ fill: {LABEL}; font: 600 17px {FONT}; }}')
    out.append('    /* Windows High Contrast Mode: the glow and the fixed palette are')
    out.append('       both dropped, so fall back to the user\'s own colours. */')
    out.append('    @media (forced-colors: active) {')
    out.append('      .ng-bg { fill: Canvas; }')
    out.append('      .ng-edge { stroke: CanvasText; }')
    out.append('      .ng-node, .ng-endpoint { fill: Canvas; stroke: CanvasText; stroke-width: 2; }')
    out.append('      .ng-num, .ng-label { fill: CanvasText; }')
    out.append('      .ng-glow { filter: none; }')
    out.append('    }')
    out.append('  </style>')
    out.append('  <defs>')
    out.append('    <filter id="netgraph-glow" x="-20%" y="-20%" width="140%" height="140%">')
    out.append('      <feGaussianBlur stdDeviation="2.5" result="blur"/>')
    out.append('      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>')
    out.append('    </filter>')
    out.append('  </defs>')
    out.append(f'  <rect class="ng-bg" width="{W}" height="{H}"/>')

    out.append('  <g class="ng-glow" filter="url(#netgraph-glow)">')
    out.append('    <g class="ng-edges">')
    for u, v in EDGES:
        x1, y1 = POS[u]
        x2, y2 = POS[v]
        out.append(
            f'      <line class="ng-edge" data-from="{name[u]}" data-to="{name[v]}" '
            f'x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"/>'
        )
    out.append('    </g>')
    out.append('    <g class="ng-nodes">')
    for k in ['S'] + RELAYS + ['R']:
        x, y = POS[k]
        endpoint = k in ('S', 'R')
        role = 'sender' if k == 'S' else 'receiver' if k == 'R' else 'relay'
        out.append(
            f'      <g class="ng-node-group" data-node="{name[k]}" data-role="{role}" '
            f'data-x="{x}" data-y="{y}">'
        )
        out.append(
            f'        <circle class="{"ng-endpoint" if endpoint else "ng-node"}" '
            f'cx="{x}" cy="{y}" r="{R_END if endpoint else R_NODE}"/>'
        )
        if not endpoint:
            out.append(f'        <text class="ng-num" x="{x}" y="{y + 4.5}">{name[k]}</text>')
        out.append('      </g>')
    out.append('    </g>')
    out.append('  </g>')

    out.append('  <g class="ng-labels">')
    for k in ('S', 'R'):
        x, y = POS[k]
        out.append(
            f'    <text class="ng-label" x="{x + R_END + 7}" y="{y + 6}">{name[k]}</text>'
        )
    out.append('  </g>')
    out.append('</svg>')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    for key, lang in LANGS.items():
        suffix = '' if key == 'en' else f'.{key}'
        path = os.path.join(REPO, 'img', '4-internet', f'redundant-2{suffix}.svg')
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(build(lang))
        print('wrote', os.path.relpath(path, REPO))
