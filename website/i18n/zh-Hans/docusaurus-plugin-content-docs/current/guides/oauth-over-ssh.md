---
sidebar_position: 17
title: "SSH / 远程主机上的 OAuth"
description: "当 Wenshu 运行在远程机器、容器或跳板机后面时，如何完成远程 MCP 服务器的浏览器 OAuth"
---

# SSH / 远程主机上的 OAuth

Linear、Sentry、Atlassian、Asana、Figma 等远程 MCP 服务器可使用回环重定向 OAuth。认证服务器会把浏览器重定向到 `http://127.0.0.1:<port>/callback`，由 Wenshu 等待授权码。

当 Wenshu 运行在远程主机时，浏览器中的 `127.0.0.1` 指向本地笔记本，而不是远程主机。可以把重定向 URL 粘贴回 Wenshu，也可以通过 SSH 转发回调端口。

**xAI Grok OAuth（`xai-oauth`）使用设备代码**，无需回环回调或 SSH 隧道；详见 [xAI Grok OAuth](./xai-grok-oauth.md)。

## 推荐：粘贴重定向 URL

在远程主机运行：

```bash
wenshu mcp login <server>
```

在本地浏览器打开打印的授权 URL。批准后，回环重定向可能显示连接失败；这是正常现象。复制浏览器地址栏中的完整 URL，并粘贴到 Wenshu 提示符。也可只粘贴 `?code=...&state=...` 查询字符串。

此交互方式无需修改 SSH 配置，适用于所有配置了 `auth: oauth` 的 MCP 服务器。

## 备选：SSH 端口转发

Wenshu 会在 SSH 会话提示中打印回调端口。在本地另开终端，转发该端口：

```bash
ssh -N -L <port>:127.0.0.1:<port> user@remote-host
```

然后正常打开授权 URL。浏览器访问隧道本地端，SSH 把回调转发到远程监听器。登录成功前请保持隧道运行。

通过跳板机时使用 `-J`：

```bash
ssh -N -L <port>:127.0.0.1:<port> -J jump-user@jump-host user@final-host
```

## 为什么监听器保持在回环地址

OAuth 服务器会根据白名单校验 `redirect_uri`，通常要求回环形式。绑定到 `0.0.0.0` 或更换回调端口可能造成重定向不匹配。粘贴 URL 或转发准确端口既能保留注册的回调 URI，也不会公开暴露监听器。

## 故障排查

- **端口已占用：** 使用 Wenshu 最新打印的端口并重启 SSH 转发。
- **授权超时：** 确认隧道仍在运行，或重新发起流程并粘贴最新重定向 URL。
- **配置热加载 30 秒超时：** 在新终端运行 `wenshu mcp login <server>`，该命令会等待交互式 OAuth 完成。
- **Token 写入错误用户：** 使用与 gateway 或系统服务相同的操作系统用户执行登录。

## 另请参阅

- [xAI Grok OAuth](./xai-grok-oauth.md)
- [原生 MCP 客户端（OAuth 部分）](../user-guide/features/mcp.md#oauth-authenticated-http-servers)
- [SSH `-J` / ProxyJump](https://man.openbsd.org/ssh#J)
