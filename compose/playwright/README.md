# Playwright MCP

`playwright` runs the official Playwright MCP image with a persistent Chromium
profile. Its MCP HTTP endpoint binds only to the Apps VM loopback interface;
it has no network exposure beyond an authenticated SSH session to Apps.

`ansible/playbooks/playwright.yml` maintains the required loopback-only SSH
tunnel on Ops.

Then add this MCP server to the local Codex configuration:

```toml
[mcp_servers.playwright]
url = "http://127.0.0.1:8931/mcp"
default_tools_approval_mode = "writes"
disabled_tools = ["browser_run_code_unsafe"]
```

Restart Codex after saving the configuration. `writes` keeps navigation and
inspection available while prompting before form changes. Keep the tunnel open
for the entire task. The browser profile contains website sessions; clear
`/srv/compose/playwright/data` only when you intentionally want to sign out
everywhere.
