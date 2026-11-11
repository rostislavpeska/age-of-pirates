import test from 'node:test';
import assert from 'node:assert/strict';
import { Renderer } from '../../viewer/lib/render.js';
import { MeshSkin } from '../../viewer/lib/skin.js';
import { GameRenderer } from '../../viewer/shading/renderer.js';

function fakeGL() {
  let bound;
  const pointers = [], uploads = [];
  let next = 0;
  const gl = new Proxy({ pointers, uploads,
    createBuffer: () => ({ id: ++next }),
    bindBuffer: (type, buffer) => { if (type === 'ARRAY_BUFFER') bound = buffer; },
    bufferData: (_type, bytes) => uploads.push([...bytes]),
    vertexAttribPointer: (loc, ...args) => pointers.push({ loc, buffer: bound, args }),
    vertexAttribIPointer: (loc, ...args) => pointers.push({ loc, buffer: bound, args }),
  }, { get: (target, key) => key in target ? target[key] : /^[A-Z0-9_]+$/.test(key) ? key : () => ({}) });
  return gl;
}

test('vertex attributes and tangents use their declared buffers, not a hard-coded geo', () => {
  const gl = fakeGL();
  const buffers = { positions: { id: 'positions' }, uv: { id: 'uv' }, tangent: { id: 'tangent' } };
  const stream = (buffer, components) => ({ view: { buffer, components, dtype: 'f32', byteOffset: 16 } });
  const mesh = { streams: { Position: stream('positions', 3), TextureCoordinates0: stream('uv', 2),
    Tangent: stream('tangent', 4) }, indices: { dtype: 'u16', count: 3 }, bone_bindings: [] };
  const skin = new MeshSkin(gl, (id) => buffers[id], mesh, () => new Uint16Array([0, 1, 2]));
  assert.equal(gl.pointers.find((p) => p.loc === 0).buffer, buffers.positions);
  assert.equal(gl.pointers.find((p) => p.loc === 2).buffer, buffers.uv);
  GameRenderer.prototype.bindTangent.call({ gl, arrayBuffer: (id) => buffers[id] }, skin, mesh);
  assert.equal(gl.pointers.at(-1).buffer, buffers.tangent);
  assert.equal(gl.pointers.at(-1).args.at(-1), 16);
});

test('buffer cache uploads exact named bytes once and refuses missing buffers', () => {
  const gl = fakeGL();
  const context = { gl, arrayBuffers: new Map(), bundle: { buffers: {
    first: new Uint8Array([1, 2]).buffer, second: new Uint8Array([7, 8, 9]).buffer } } };
  const first = Renderer.prototype.arrayBuffer.call(context, 'first');
  assert.equal(Renderer.prototype.arrayBuffer.call(context, 'first'), first);
  assert.notEqual(Renderer.prototype.arrayBuffer.call(context, 'second'), first);
  assert.deepEqual(gl.uploads, [[1, 2], [7, 8, 9]]);
  assert.throws(() => Renderer.prototype.arrayBuffer.call(context, 'missing'), /missing vertex buffer missing/);
});
