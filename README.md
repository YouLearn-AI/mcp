# YouLearn MCP

Remote MCP server for [YouLearn](https://youlearn.ai). Lets AI agents ingest content (YouTube videos, PDFs, audio, video, webpages) into your YouLearn library and pull transcripts and AI summaries back out.

**Endpoint:** `https://api.youlearn.ai/mcp/`

Auth is OAuth — sign in with your YouLearn account the first time you connect. No API keys to manage.

## Install

Most MCP clients accept a `mcpServers` block in their config. The canonical entry is:

```json
{
  "mcpServers": {
    "youlearn": {
      "type": "http",
      "url": "https://api.youlearn.ai/mcp/"
    }
  }
}
```

Paste that into whatever your client calls its MCP config file:

| Client | Where to put it |
| --- | --- |
| Claude Code | `claude mcp add --transport http youlearn https://api.youlearn.ai/mcp/` |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) · `%APPDATA%\Claude\claude_desktop_config.json` (Windows) |
| Cursor | `~/.cursor/mcp.json` |
| VS Code (Copilot Chat) | `.vscode/mcp.json` in the workspace, or user settings |
| Windsurf, Zed, Cline | Same JSON, in their respective config locations |

For clients that don't yet speak remote MCP natively, use the [`mcp-remote`](https://www.npmjs.com/package/mcp-remote) shim:

```json
{
  "mcpServers": {
    "youlearn": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://api.youlearn.ai/mcp/"]
    }
  }
}
```

Restart the client. The first tool call opens a browser to sign in; after that, sessions reuse the token automatically.

## Tools

- **`ingest_url_tool(url, title?)`** — Adds a YouTube video, PDF, audio, video, or webpage to your YouLearn library. Returns `content_id`, `title`, and `type`.
- **`get_transcript_tool(content_id)`** — Full transcript as text segments with timestamps.
- **`export_transcript_tool(content_id, format)`** — Transcript as `json`, `txt`, `srt`, or `vtt`.
- **`get_summary_tool(content_id, template?)`** — AI summary. Templates: `detailed`, `brief`, `outline`, `cornell_notes`.

Typical flow: ingest a URL, hold onto the `content_id`, then call the transcript or summary tools with it.

## Example prompts

> Ingest this YouTube video into YouLearn and give me the Cornell-notes summary: `https://www.youtube.com/watch?v=...`

> Add this arXiv PDF to YouLearn and summarize it in the outline template.

> Export the transcript of content `J6b5xbib2GrYxTX` as an SRT file.

## Limits

- Plan limits apply — free-tier accounts hit ingest caps. The tool response includes an upgrade link when that happens.
- Access tokens expire after 1 hour; clients re-auth automatically.
- Only URLs are accepted for ingestion. Uploading raw files isn't supported over MCP yet.

## Issues

Something broken? Ping us in [Discord](https://discord.gg/youlearn) or open an issue on this repo.

## License

[MIT](LICENSE).
