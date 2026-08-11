/* Network Graph Explorer
 *
 * Turns a `[data-network-graph]` container into an accessible, interactive
 * version of a network diagram: the SVG named by the attribute is inlined, and
 * a checkbox per relay node lets a reader switch nodes off and see whether the
 * Sender can still reach the Receiver.
 *
 * The topology is read back out of the SVG's own data- attributes, so the .svg
 * file stays the single source of truth for the drawing *and* the graph. The
 * contract an SVG has to satisfy is documented in docs/style_guide.html.
 *
 * Accessibility notes:
 *  - The controls are real <input type="checkbox"> elements, so keyboard and
 *    screen-reader support is the browser's, not ours. Clicking a node in the
 *    picture is a mouse-only shortcut that toggles the same checkbox.
 *  - Switched-off nodes get an ✕ badge as well as a duller fill, so the state
 *    is never carried by colour alone.
 *  - Every change is reported in words through a role="status" region, and the
 *    <details> panel restates the whole graph as text -- including which nodes
 *    are currently off -- for anyone who can't use the picture at all.
 *  - Without JavaScript (or if the fetch fails) the container keeps the plain
 *    <img> it was authored with.
 */

(function () {
    'use strict';

    var READY = 'data-network-graph-ready';
    var SENDER = 'sender';
    var RECEIVER = 'receiver';
    var RELAY = 'relay';
    var SVG_NS = 'http://www.w3.org/2000/svg';
    var XLINK_NS = 'http://www.w3.org/1999/xlink';

    var t = llab.translate;

    // Registered with the shared table so `llab.t` finds them; kept in this
    // file because the widget's CSS and JS only load on pages that use it.
    var STRINGS = {
        'netGraphLegend': {
            en: 'Switch nodes off to see whether the message still gets through',
            es: 'Apaga nodos para ver si el mensaje aún llega',
        },
        'netGraphNode': {
            en: 'Node %{n}',
            es: 'Nodo %{n}',
        },
        'netGraphReset': {
            en: 'Turn all nodes back on',
            es: 'Volver a encender todos los nodos',
        },
        'netGraphAllOn': {
            en: 'All %{count} relay nodes are working. Switch some off to see whether a message can still get through.',
            es: 'Los %{count} nodos de retransmisión funcionan. Apaga algunos para ver si un mensaje todavía puede llegar.',
        },
        'netGraphStillWorks': {
            en: 'Switched off: %{nodes}. A message still gets through. One path that works:',
            es: 'Apagados: %{nodes}. El mensaje todavía llega. Un camino que funciona:',
        },
        'netGraphBroken': {
            en: 'Switched off: %{nodes}. No path is left: the Sender cannot reach the Receiver.',
            es: 'Apagados: %{nodes}. No queda ningún camino: el emisor no puede llegar al receptor.',
        },
        'netGraphThen': {
            en: ', then ',
            es: ', luego ',
        },
        'netGraphDescribe': {
            en: 'Describe this network in words',
            es: 'Describir esta red con palabras',
        },
        'netGraphConnects': {
            en: '%{node} connects to %{list}',
            es: '%{node} se conecta con %{list}',
        },
        'netGraphOff': {
            en: '%{node} (switched off)',
            es: '%{node} (apagado)',
        },
    };
    Object.keys(STRINGS).forEach(function (key) { llab.TRANSLATIONS[key] = STRINGS[key]; });

    /* ------------------------------------------------------------------ */
    /* Loading the drawing                                                 */

    // Both questions on a page usually show the same diagram; one request is
    // enough. Mirrors llab.fetchTopicFile's reason for existing.
    var pending = {};

    function fetchSVG(url) {
        if (!pending[url]) {
            pending[url] = fetch(url).then(function (response) {
                if (!response.ok) { throw new Error('HTTP ' + response.status); }
                return response.text();
            });
            // A failed fetch shouldn't poison later attempts.
            pending[url].catch(function () { delete pending[url]; });
        }
        return pending[url];
    }

    /* Two copies of the same diagram can appear on one page (both questions on
     * the network-redundancy pages use it), so every id in the inlined SVG has
     * to be made unique before it joins the document. Only the reference forms
     * the SVGs actually use are rewritten -- including id selectors inside the
     * SVG's own <style>, which a broader attribute sweep would silently miss. */
    var URL_REF_ATTRS = ['filter', 'fill', 'stroke', 'clip-path', 'mask', 'marker-end',
                         'marker-start', 'marker-mid'];
    var ID_LIST_ATTRS = ['aria-labelledby', 'aria-describedby'];
    var HREF_ATTRS = ['href', 'xlink:href'];

    function scopeIds(svg, prefix) {
        var renamed = {};
        svg.querySelectorAll('[id]').forEach(function (el) {
            renamed[el.id] = prefix + '-' + el.id;
            el.id = renamed[el.id];
        });
        var oldIds = Object.keys(renamed);
        if (!oldIds.length) { return; }

        [svg].concat(Array.prototype.slice.call(svg.querySelectorAll('*')))
            .forEach(function (el) {
                URL_REF_ATTRS.forEach(function (attrName) {
                    var value = el.getAttribute(attrName);
                    if (!value || value.indexOf('url(#') === -1) { return; }
                    oldIds.forEach(function (old) {
                        value = value.split('url(#' + old + ')')
                            .join('url(#' + renamed[old] + ')');
                    });
                    el.setAttribute(attrName, value);
                });
                ID_LIST_ATTRS.forEach(function (attrName) {
                    var value = el.getAttribute(attrName);
                    if (!value) { return; }
                    el.setAttribute(attrName, value.trim().split(/\s+/).map(function (token) {
                        return renamed[token] || token;
                    }).join(' '));
                });
                HREF_ATTRS.forEach(function (attrName) {
                    var value = el.getAttribute(attrName);
                    if (!value || value.charAt(0) !== '#') { return; }
                    var target = renamed[value.slice(1)];
                    if (!target) { return; }
                    // setAttribute would mint a null-namespace attribute
                    // literally called "xlink:href", which SVG ignores.
                    if (attrName === 'xlink:href') {
                        el.setAttributeNS(XLINK_NS, attrName, '#' + target);
                    } else {
                        el.setAttribute(attrName, '#' + target);
                    }
                });
            });

        svg.querySelectorAll('style').forEach(function (style) {
            var css = style.textContent;
            oldIds.forEach(function (old) {
                css = css.split('#' + old).join('#' + renamed[old]);
            });
            style.textContent = css;
        });
    }

    /* ------------------------------------------------------------------ */
    /* The graph                                                           */

    function isOff(node) {
        // The checkbox is the state; nothing else needs to remember it.
        return !!(node.checkbox && node.checkbox.checked);
    }

    function readGraph(svg) {
        var nodes = [];
        var byName = {};
        svg.querySelectorAll('[data-node]').forEach(function (el) {
            var node = {
                name: el.getAttribute('data-node'),
                role: el.getAttribute('data-role'),
                el: el,
                neighbours: [],
            };
            nodes.push(node);
            byName[node.name] = node;
        });

        var edges = [];
        svg.querySelectorAll('[data-from][data-to]').forEach(function (el) {
            var from = byName[el.getAttribute('data-from')];
            var to = byName[el.getAttribute('data-to')];
            if (!from || !to) { return; }
            edges.push({ from: from, to: to, el: el });
            from.neighbours.push(to);
            to.neighbours.push(from);
        });

        // Edges are listed in drawing order; the text alternative reads far
        // better with each node's neighbours in Sender, 1..n, Receiver order.
        var relays = nodes.filter(function (n) { return n.role === RELAY; });
        var order = {};
        nodes.forEach(function (n) {
            order[n.name] = n.role === SENDER ? -1 : nodes.length;
        });
        relays.forEach(function (n, i) { order[n.name] = i; });
        nodes.forEach(function (node) {
            node.neighbours.sort(function (a, b) { return order[a.name] - order[b.name]; });
        });

        return {
            nodes: nodes,
            edges: edges,
            byName: byName,
            relays: relays,
            sender: nodes.filter(function (n) { return n.role === SENDER; })[0],
            receiver: nodes.filter(function (n) { return n.role === RECEIVER; })[0],
        };
    }

    /* Shortest surviving Sender -> Receiver path, or null if there isn't one. */
    function findPath(graph) {
        var cameFrom = {};
        cameFrom[graph.sender.name] = null;
        var queue = [graph.sender];

        while (queue.length) {
            var current = queue.shift();
            if (current === graph.receiver) {
                var path = [];
                for (var node = current; node; node = cameFrom[node.name]) {
                    path.unshift(node);
                }
                return path;
            }
            current.neighbours.forEach(function (next) {
                if (isOff(next) || next.name in cameFrom) { return; }
                cameFrom[next.name] = current;
                queue.push(next);
            });
        }
        return null;
    }

    /* ------------------------------------------------------------------ */
    /* Building the widget                                                 */

    function markNodeAsFailable(node) {
        // A small ✕ badge on the node's shoulder rather than across its middle,
        // which would hide the number that identifies it. Hidden by CSS until
        // the node is actually off.
        var bx = Number(node.el.getAttribute('data-x')) + 8;
        var by = Number(node.el.getAttribute('data-y')) - 8;
        var reach = 3.4;

        var disc = document.createElementNS(SVG_NS, 'circle');
        disc.setAttribute('class', 'node-cross-badge');
        disc.setAttribute('cx', bx);
        disc.setAttribute('cy', by);
        disc.setAttribute('r', 6.5);

        var cross = document.createElementNS(SVG_NS, 'path');
        cross.setAttribute('class', 'node-cross');
        cross.setAttribute('d',
            'M' + (bx - reach) + ' ' + (by - reach) + 'L' + (bx + reach) + ' ' + (by + reach) +
            'M' + (bx + reach) + ' ' + (by - reach) + 'L' + (bx - reach) + ' ' + (by + reach));

        node.el.appendChild(disc);
        node.el.appendChild(cross);
    }

    function template(graph, prefix) {
        // "-ctl-" keeps these out of the namespace scopeIds mints for the
        // drawing's own ids, which are `prefix + '-' + id`.
        var toggles = graph.relays.map(function (node) {
            var id = prefix + '-ctl-' + node.name;
            return `<label class="network-explorer-toggle" for="${id}">
                        <input type="checkbox" id="${id}" value="${node.name}">
                        <span>${t('netGraphNode', { n: node.name })}</span>
                    </label>`;
        }).join('');

        return `
<div class="network-explorer-figure"></div>
<fieldset class="network-explorer-controls">
    <legend>${t('netGraphLegend')}</legend>
    <div class="network-explorer-toggles">${toggles}</div>
    <button type="button" class="network-explorer-reset" disabled>${t('netGraphReset')}</button>
</fieldset>
<p class="network-explorer-status" role="status"></p>
<details class="network-explorer-text">
    <summary>${t('netGraphDescribe')}</summary>
    <ul>${graph.nodes.map(function () { return '<li></li>'; }).join('')}</ul>
</details>`;
    }

    /* The visible path uses arrows; screen readers get the word instead, so
     * they don't read out "right arrow" between every node. */
    function pathMarkup(path) {
        return path.map(function (node, index) {
            var step = `<span class="network-explorer-step">${node.name}</span>`;
            if (index === 0) { return step; }
            return `<span aria-hidden="true"> → </span>` +
                `<span class="visually-hidden">${t('netGraphThen')}</span>` + step;
        }).join('');
    }

    function label(node) {
        return isOff(node) ? t('netGraphOff', { node: node.name }) : node.name;
    }

    function render(widget) {
        var graph = widget.graph;
        var offNodes = graph.relays.filter(isOff);
        var path = findPath(graph);

        // Only highlight a path once something has been switched off; showing
        // one up front would suggest it is *the* route.
        var showPath = path && offNodes.length > 0;
        var onPath = {};
        var pathSteps = {};
        if (showPath) {
            path.forEach(function (node, index) {
                onPath[node.name] = true;
                if (index > 0) {
                    pathSteps[[path[index - 1].name, node.name].sort().join('\n')] = true;
                }
            });
        }

        graph.nodes.forEach(function (node) {
            node.el.classList.toggle('is-off', isOff(node));
            node.el.classList.toggle('is-path', !!onPath[node.name]);
        });
        graph.edges.forEach(function (edge) {
            edge.el.classList.toggle('is-off', isOff(edge.from) || isOff(edge.to));
            edge.el.classList.toggle('is-path',
                !!pathSteps[[edge.from.name, edge.to.name].sort().join('\n')]);
        });

        widget.reset.disabled = offNodes.length === 0;

        var names = offNodes.map(function (n) { return n.name; }).join(', ');
        var status;
        if (!offNodes.length) {
            status = t('netGraphAllOn', { count: graph.relays.length });
        } else if (path) {
            status = t('netGraphStillWorks', { nodes: names }) + ' ' + pathMarkup(path) + '.';
        } else {
            status = t('netGraphBroken', { nodes: names });
        }
        widget.status.html(status).toggleClass('is-broken', !path);

        // The text alternative has to track the state too, or the only
        // non-visual view of the graph contradicts the picture.
        graph.nodes.forEach(function (node, index) {
            widget.descriptions.eq(index).text(t('netGraphConnects', {
                node: label(node),
                list: node.neighbours.map(label).join(', '),
            }));
        });
    }

    /* ------------------------------------------------------------------ */

    // Kept on llab rather than in this closure: dynamic navigation re-injects
    // this script, and the counter has to keep climbing so a re-run can't
    // reuse an id prefix that is still in the document.
    llab.networkGraphInstances = llab.networkGraphInstances || 0;

    function build(container, markup) {
        var parsed = new DOMParser().parseFromString(markup, 'image/svg+xml');
        var svg = parsed.documentElement;
        if (!svg || svg.nodeName.toLowerCase() !== 'svg') {
            throw new Error('not an SVG document');
        }

        llab.networkGraphInstances += 1;
        var prefix = 'netgraph-' + llab.networkGraphInstances;
        svg = document.importNode(svg, true);
        scopeIds(svg, prefix);
        svg.removeAttribute('width');
        svg.removeAttribute('height');
        // The <desc> restates the whole adjacency list, which the <details>
        // panel below now covers -- and unlike <desc> that one stays in step
        // with which nodes are switched off.
        svg.removeAttribute('aria-describedby');

        var graph = readGraph(svg);
        if (!graph.sender || !graph.receiver || !graph.relays.length) {
            throw new Error('SVG has no sender/receiver/relay topology');
        }
        graph.relays.forEach(markNodeAsFailable);

        var $container = $(container).addClass('network-explorer').html(template(graph, prefix));
        var widget = {
            graph: graph,
            reset: $container.find('.network-explorer-reset')[0],
            status: $container.find('.network-explorer-status'),
            descriptions: $container.find('.network-explorer-text li'),
        };

        $container.find('.network-explorer-figure').append(svg);
        // The template emits one checkbox per relay, in order.
        $container.find('input[type="checkbox"]')
            .each(function (index) { graph.relays[index].checkbox = this; })
            .on('change', function () { render(widget); });

        $(widget.reset).on('click', function () {
            graph.relays.forEach(function (node) { node.checkbox.checked = false; });
            render(widget);
            // Focus would otherwise be stranded on the now-disabled button.
            graph.relays[0].checkbox.focus();
        });

        // Mouse shortcut: clicking a node in the picture flips its checkbox.
        // The checkboxes remain the accessible control surface.
        $container.find('.network-explorer-figure').on('click', function (event) {
            var group = event.target.closest('[data-node]');
            if (!group || group.getAttribute('data-role') !== RELAY) { return; }
            var node = graph.byName[group.getAttribute('data-node')];
            if (!node) { return; }
            node.checkbox.checked = !node.checkbox.checked;
            render(widget);
        });

        render(widget);
        container.setAttribute(READY, 'true');
    }

    // Tracked off the DOM: the quiz builder copies a question's prompt as an
    // HTML *string*, so a marker attribute could be duplicated onto a fresh
    // copy that has never actually been set up.
    var started = new WeakSet();

    function setup(container) {
        if (started.has(container)) { return; }
        started.add(container);

        fetchSVG(container.getAttribute('data-network-graph'))
            .then(function (markup) { build(container, markup); })
            .catch(function () {
                // Leave the authored <img> in place; it is still a correct,
                // scalable version of the diagram, just not an explorable one.
                container.setAttribute(READY, 'failed');
            });
    }

    llab.setupNetworkGraphs = function () {
        document.querySelectorAll('[data-network-graph]').forEach(setup);
    };

    // Self-check questions are re-rendered from an HTML string during
    // $(document).ready, which can land after this script's onload. Ready
    // handlers run in registration order, so this one sees the final markup.
    if (!llab.networkGraphReadyHooked) {
        llab.networkGraphReadyHooked = true;
        $(function () { llab.setupNetworkGraphs(); });
    }
}());
