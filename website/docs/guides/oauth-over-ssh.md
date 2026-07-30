---
sidebar_position: 17
title: "OAuth over SSH / Remote Hosts"
description: "How to complete browser-based OAuth for remote MCP servers when Wenshu runs on a remote machine, container, or behind a jump box"
---

# OAuth over SSH / Remote Hosts

Remote MCP servers such as Linear, Sentry, Atlassian, Asana, and Figma can use a loopback-redirect OAuth flow. The authorization server redirects the browser to `http://127.0.0.1:<port>/callback`, where Wenshu waits for the authorization code.

When Wenshu runs remotely, the browser's `127.0.0.1` is the local laptop rather than the remote host. Complete the flow either by pasting the redirect URL back into Wenshu or by forwarding the callback port over SSH.

**xAI Grok OAuth (`xai-oauth`) uses OAuth device code**, not a loopback callback. It does not need an SSH tunnel; see [xAI Grok OAuth](./xai-grok-oauth.md).

## Recommended: paste the redirect URL

Run the login from the remote host:

```bash
wenshu mcp login <server>
```

Open the printed authorization URL in a local browser. After approval, the loopback redirect may show a connection error. Copy the full URL from the browser address bar and paste it at the Wenshu prompt. A bare `?code=...&state=...` query string is also accepted.

This interactive path needs no SSH configuration and works for any MCP server configured with `auth: oauth`.

## Alternative: SSH port forwarding

Wenshu prints the callback port in its SSH-session hint. In a separate local terminal, forward that exact port:

```bash
ssh -N -L <port>:127.0.0.1:<port> user@remote-host
```

Then open the authorization URL normally. The browser reaches the local side of the tunnel, and SSH forwards the callback to Wenshu's remote listener. Keep the tunnel open until login succeeds.

For a bastion or jump host, use `-J`:

```bash
ssh -N -L <port>:127.0.0.1:<port> -J jump-user@jump-host user@final-host
```

## Why the listener stays on loopback

OAuth servers validate `redirect_uri` against an allowlist and commonly require the loopback form. Binding the listener to `0.0.0.0` or changing the callback port can cause a redirect mismatch. Pasting the URL or forwarding the exact port preserves the registered callback URI without exposing the listener publicly.

## Troubleshooting

- **Port already in use:** use the latest port printed by Wenshu and restart the SSH forward.
- **Authorization timed out:** confirm the tunnel is alive or repeat the flow and paste the newest redirect URL.
- **30-second config reload timeout:** use `wenshu mcp login <server>` from a fresh terminal; it waits for the interactive OAuth flow.
- **Tokens saved for the wrong user:** run login as the same OS user that runs the gateway or service.

## See Also

- [xAI Grok OAuth](./xai-grok-oauth.md)
- [Native MCP client (OAuth section)](../user-guide/features/mcp.md#oauth-authenticated-http-servers)
- [SSH `-J` / ProxyJump](https://man.openbsd.org/ssh#J)
