"""
Shared platform registry for 文枢.

Single source of truth for platform metadata consumed by both
skills_config (label display) and tools_config (default toolset
resolution).  Import ``PLATFORMS`` from here instead of maintaining
duplicate dicts in each module.
"""

from collections import OrderedDict
from typing import NamedTuple


class PlatformInfo(NamedTuple):
    """Metadata for a single platform entry."""
    label: str
    default_toolset: str


# Ordered so that TUI menus are deterministic.
PLATFORMS: OrderedDict[str, PlatformInfo] = OrderedDict([
    ("cli",            PlatformInfo(label="🖥️  CLI",            default_toolset="wenshu-cli")),
    ("telegram",       PlatformInfo(label="📱 Telegram",        default_toolset="wenshu-telegram")),
    ("discord",        PlatformInfo(label="💬 Discord",         default_toolset="wenshu-discord")),
    ("slack",          PlatformInfo(label="💼 Slack",           default_toolset="wenshu-slack")),
    ("whatsapp",       PlatformInfo(label="📱 WhatsApp",        default_toolset="wenshu-whatsapp")),
    ("whatsapp_cloud", PlatformInfo(label="📱 WhatsApp Business (Cloud)", default_toolset="wenshu-whatsapp")),
    ("signal",         PlatformInfo(label="📡 Signal",          default_toolset="wenshu-signal")),
    ("bluebubbles",    PlatformInfo(label="💙 BlueBubbles",     default_toolset="wenshu-bluebubbles")),
    ("email",          PlatformInfo(label="📧 Email",           default_toolset="wenshu-email")),
    ("homeassistant",  PlatformInfo(label="🏠 Home Assistant",  default_toolset="wenshu-homeassistant")),
    ("mattermost",     PlatformInfo(label="💬 Mattermost",      default_toolset="wenshu-mattermost")),
    ("matrix",         PlatformInfo(label="💬 Matrix",          default_toolset="wenshu-matrix")),
    ("dingtalk",       PlatformInfo(label="💬 DingTalk",        default_toolset="wenshu-dingtalk")),
    ("feishu",         PlatformInfo(label="🪽 Feishu",          default_toolset="wenshu-feishu")),
    ("wecom",          PlatformInfo(label="💬 WeCom",           default_toolset="wenshu-wecom")),
    ("wecom_callback", PlatformInfo(label="💬 WeCom Callback",  default_toolset="wenshu-wecom-callback")),
    ("weixin",         PlatformInfo(label="💬 Weixin",          default_toolset="wenshu-weixin")),
    ("qqbot",          PlatformInfo(label="💬 QQBot",           default_toolset="wenshu-qqbot")),
    ("yuanbao",        PlatformInfo(label="🤖 Yuanbao",         default_toolset="wenshu-yuanbao")),
    ("webhook",        PlatformInfo(label="🔗 Webhook",         default_toolset="wenshu-webhook")),
    ("api_server",     PlatformInfo(label="🌐 API Server",      default_toolset="wenshu-api-server")),
    ("cron",           PlatformInfo(label="⏰ Cron",            default_toolset="wenshu-cron")),
])


def platform_label(key: str, default: str = "") -> str:
    """Return the display label for a platform key, or *default*.

    Checks the static PLATFORMS dict first, then the plugin platform
    registry for dynamically registered platforms.
    """
    info = PLATFORMS.get(key)
    if info is not None:
        return info.label
    # Check plugin registry
    try:
        from gateway.platform_registry import platform_registry
        entry = platform_registry.get(key)
        if entry:
            return f"{entry.emoji}  {entry.label}" if entry.emoji else entry.label
    except Exception:
        pass
    return default


def get_all_platforms() -> "OrderedDict[str, PlatformInfo]":
    """Return PLATFORMS merged with any plugin-registered platforms.

    Plugin platforms are appended after builtins.  This is the function
    that tools_config and skills_config should use for platform menus.
    """
    merged = OrderedDict(PLATFORMS)
    try:
        from gateway.platform_registry import platform_registry
        for entry in platform_registry.plugin_entries():
            if entry.name not in merged:
                merged[entry.name] = PlatformInfo(
                    label=f"{entry.emoji}  {entry.label}" if entry.emoji else entry.label,
                    default_toolset=f"wenshu-{entry.name}",
                )
    except Exception:
        pass
    return merged
