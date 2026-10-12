"""Optional stdio MCP adapter for owned hidden native batch processes."""
from mcp.server.fastmcp import FastMCP
from armorpaint_batch import runtime, run_script, export

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
    """Export five native PNG maps to a new/empty directory; verify files, decoding, size and input identity."""
    return export(runtime(), project_path, output_directory, resolution, timeout_seconds)

if __name__ == '__main__':
    mcp.run(transport='stdio')
