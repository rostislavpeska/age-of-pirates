"""Optional stdio MCP adapter for owned hidden native batch processes."""
from mcp.server.fastmcp import FastMCP
from armorpaint_batch import runtime, run_script, export, resize

mcp = FastMCP('ArmorPaint native batch')

@mcp.tool()
def armorpaint_run_script(input_path: str, script_path: str, output_directory: str,
                         expected_outputs: list[str], completion_marker: str,
                         timeout_seconds: float = 120) -> dict:
    """Run a trusted native script against a source copy; verify fresh outputs and preserve input hashes."""
    return run_script(runtime(), input_path, script_path, output_directory,
                      expected_outputs, completion_marker, timeout_seconds)

@mcp.tool()
def armorpaint_export_textures(project_path: str, output_directory: str,
                              resolution: int = 2048, timeout_seconds: float = 120) -> dict:
    """Export five PNG maps; resolution validates the existing project size, it does not resize it."""
    return export(runtime(), project_path, output_directory, resolution, timeout_seconds)

@mcp.tool()
def armorpaint_resize_project(project_path: str, output_directory: str,
                              resolution: int, timeout_seconds: float = 120) -> dict:
    """Save a new project at explicit resolution and verify reopened PNG export; requires native extension."""
    return resize(runtime(), project_path, output_directory, resolution, timeout_seconds)

if __name__ == '__main__':
    mcp.run(transport='stdio')
