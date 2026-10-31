// Page <-> local server messages (scripts/server.py). The run token comes from the page's own ?token= query and goes
// back in the X-AV-Token header; the server refuses any post without it. Browser-only module.

const params = new URLSearchParams(globalThis.location ? globalThis.location.search : '');
export const TOKEN = params.get('token') || '';
export const TEST_MODE = params.get('test') === '1';
export const PARAMS = params;

export async function post(path, body, contentType = 'application/json') {
  const r = await fetch(path, {
    method: 'POST',
    headers: { 'X-AV-Token': TOKEN, 'Content-Type': contentType },
    body,
  });
  if (!r.ok) throw new Error('POST ' + path + ' -> ' + r.status);
  return r.json();
}

export function postJSON(path, obj) {
  return post(path, JSON.stringify(obj));
}

// progress line for the agent's log (headless.py prints every one with its time); never throws
export function log(msg, level = 'info') {
  return postJSON('/api/log', { level, msg: String(msg) }).catch(() => null);
}

// a file into the server's output folder (png, json or txt; the server checks the name)
export function postFile(name, blob) {
  return post('/api/file?name=' + encodeURIComponent(name), blob, blob.type || 'application/octet-stream');
}

export function reportError(err) {
  return postJSON('/api/error', { msg: String(err && err.message ? err.message : err), stack: err && err.stack })
    .catch(() => null);
}

export function installErrorHooks() {
  globalThis.addEventListener('error', (e) => reportError(e.error || e.message));
  globalThis.addEventListener('unhandledrejection', (e) => reportError(e.reason));
}
