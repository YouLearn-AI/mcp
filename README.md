# YouLearn MCP

Ingest content into [YouLearn](https://youlearn.ai) — and pull transcripts and summaries back out — from any MCP client (Claude Code, Claude Desktop, Cursor, Windsurf, etc.).

**Endpoint:** `https://api.youlearn.ai/mcp`

Auth is OAuth — sign in with your existing YouLearn account the first time you connect. No API keys to manage.

---

## Quick start

### Claude Code

```bash
claude mcp add --transport http youlearn https://api.youlearn.ai/mcp
```

Run `/mcp` inside Claude Code and pick `youlearn` to sign in.

### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "youlearn": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://api.youlearn.ai/mcp"]
    }
  }
}
```

Restart Claude Desktop. A browser window opens on first use to sign in.

### Cursor

Add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "youlearn": {
      "url": "https://api.youlearn.ai/mcp"
    }
  }
}
```

### Any other MCP client

Point it at `https://api.youlearn.ai/mcp` as a streamable HTTP MCP server. OAuth 2.0 + dynamic client registration is supported, so most clients auto-discover everything.

---

## Tools

| Tool | What it does |
| --- | --- |
| `ingest_url_tool(url, title?)` | Adds a YouTube video, PDF, audio, video, or webpage to your YouLearn library. Returns a `content_id`. |
| `get_transcript_tool(content_id)` | Returns the transcript as text segments with timestamps. |
| `export_transcript_tool(content_id, format)` | Exports the transcript as `json`, `txt`, `srt`, or `vtt`. |
| `get_summary_tool(content_id, template?)` | Returns (or generates) an AI summary. Templates: `detailed`, `brief`, `outline`, `cornell_notes`. |

Typical flow: ingest a URL, hold onto the `content_id`, then call transcript or summary tools with it.

---

## Example prompts

> Ingest `https://www.youtube.com/watch?v=...` into YouLearn and give me the Cornell-notes summary.

> Pull the transcript of content `abc123` as an SRT file.

> Add this arXiv PDF to YouLearn and summarize it in the outline template.

---

## Local development

If you're running the YouLearn backend locally, the MCP server is mounted at `/mcp` on the same FastAPI app:

```bash
# In youlearn-backend/
make start
```

Point your client at `http://localhost:8000/mcp`. OAuth still works locally — it redirects you through Firebase sign-in just like production.

---

## Limits & auth

- Plan limits apply — free-tier users can hit ingest caps. The tool response includes an upgrade link when that happens.
- Tokens expire after 1 hour; clients re-auth automatically via the refresh flow.
- Only URLs are accepted for ingestion. Uploading raw files isn't supported over MCP yet.

---

## Issues

Something broken? Ping us in [Discord](https://discord.gg/youlearn) or open an issue here.
