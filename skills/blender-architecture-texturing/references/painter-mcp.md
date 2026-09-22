# Substance Painter MCP feasibility

Treat an MCP project's published feature list as a hypothesis until it is tested against the installed Painter version and current project.

When integration is requested, use an isolated environment and a disposable project. Probe connection status, capabilities, project and texture-set inspection, and a read-only export plan. Test every required capability instead of relying on version strings. Only after those checks pass, test a reversible layer and scratch export while preserving the original SPP.

Do not install, upgrade or modify a production project as an incidental step. Keep a Blender/image-editor fallback when required capabilities are unavailable. Use fully qualified MCP tool names in skill instructions.
