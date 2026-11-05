// node --test: viewer/lib/gl.js pure helpers.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { classifyGpuPath } from '../../viewer/lib/gl.js';

test('GPU path from the renderer string (strings seen in the M0 spike, 2026-10-11)', () => {
  assert.equal(classifyGpuPath('ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 Ti SUPER (0x00002705) Direct3D11 vs_5_0 ps_5_0, D3D11)'), 'angle-d3d11');
  assert.equal(classifyGpuPath('ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)'), 'swiftshader');
  assert.equal(classifyGpuPath('ANGLE (Intel, Intel(R) UHD Graphics Direct3D9Ex vs_3_0 ps_3_0, d3d9)'), 'angle-d3d9');
  assert.equal(classifyGpuPath('ANGLE (AMD, Vulkan 1.3 (AMD Radeon))'), 'angle-vulkan');
  assert.equal(classifyGpuPath('ANGLE (Apple, ANGLE Metal Renderer: Apple M2)'), 'angle-metal');
  assert.equal(classifyGpuPath('ANGLE (NVIDIA, OpenGL 4.6)'), 'angle-opengl');
  assert.equal(classifyGpuPath('WebKit WebGL'), 'other');
  assert.equal(classifyGpuPath(null), 'other');
});
