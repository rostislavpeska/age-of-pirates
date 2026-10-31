// Small DOM helpers shared by the timeline, the clip picker and the data panels (browser only).

// h('div', {class: 'x', onclick: fn, style: {left: '3%'}}, 'text', child, [children]) -> element
export function h(tag, attrs, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === null || v === undefined || v === false) continue;
    if (k === 'style' && typeof v === 'object') Object.assign(e.style, v);
    else if (k.startsWith('on') && typeof v === 'function') e.addEventListener(k.slice(2), v);
    else if (k === 'dataset' && typeof v === 'object') Object.assign(e.dataset, v);
    else e.setAttribute(k, v === true ? '' : String(v));
  }
  append(e, kids);
  return e;
}

export function append(e, kids) {
  for (const k of kids.flat(Infinity)) {
    if (k === null || k === undefined || k === false) continue;
    e.append(k instanceof Node ? k : document.createTextNode(String(k)));
  }
  return e;
}

const SVG = 'http://www.w3.org/2000/svg';
export function svg(tag, attrs) {
  const e = document.createElementNS(SVG, tag);
  for (const [k, v] of Object.entries(attrs || {})) e.setAttribute(k, String(v));
  return e;
}

export function clear(e) { while (e.firstChild) e.removeChild(e.firstChild); return e; }

export function fmt(x, n = 3) {
  return x === null || x === undefined || Number.isNaN(Number(x)) ? '-' : Number(x).toFixed(n);
}

export function pct(x) { return (x * 100).toFixed(1) + '%'; }

export function base(id) { return id ? String(id).split('/').pop() : '-'; }

// a table from column specs [{h, f(row) -> text|node, cls}] and rows
export function table(cols, rows, { rowClass, onRow } = {}) {
  const t = h('table', { class: 'tl-t' });
  t.append(h('tr', {}, cols.map((c) => h('th', { title: c.title || null }, c.h))));
  for (const r of rows) {
    const tr = h('tr', { class: [rowClass ? rowClass(r) : '', onRow ? 'pick' : ''].join(' ').trim() || null });
    if (onRow) tr.addEventListener('click', () => onRow(r));
    for (const c of cols) {
      const v = c.f(r);
      tr.append(h('td', { class: c.cls || null, title: c.tip ? c.tip(r) : null }, v === null || v === undefined ? '-' : v));
    }
    t.append(tr);
  }
  return t;
}
