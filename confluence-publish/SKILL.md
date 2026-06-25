---
name: confluence-publish
version: 1.0.0
description: "Publish local HTML files into Confluence 6.x wiki pages via browser automation (agent-browser + Chrome CDP). Handles HTML simplification, title extraction, TinyMCE editor injection, Unicode sanitization for old Synchrony editors, optional one-click publish via REST API, and reusable login sessions. Use when the user wants to publish, upload, or push HTML content to a Confluence wiki, create Confluence pages from local reports, or automate Confluence page creation."
description_zh: "通过浏览器自动化（agent-browser + Chrome CDP）将本地 HTML 文件发布到 Confluence 6.x Wiki 页面。支持 HTML 简化、标题提取、TinyMCE 编辑器注入、旧版 Synchrony 编辑器的 Unicode 清理、可选的一键 REST API 发布和可复用登录会话。当用户需要将 HTML 内容发布/上传/推送到 Confluence Wiki、从本地报告创建 Confluence 页面、或自动化 Confluence 页面创建时使用。"
---

# Publish HTML to Confluence Wiki

## Overview

Automate Confluence page creation from local HTML files using WSL + Windows Chrome + `agent-browser` CDP automation. The script fills the Confluence TinyMCE editor with sanitized HTML and either leaves the page open for manual review or publishes it directly via the Confluence REST API.

## Prerequisites

- WSL with `powershell.exe` accessible
- Windows Chrome installed
- `agent-browser` available on Windows PATH
- Python package `beautifulsoup4` (`pip install beautifulsoup4`)
- A Confluence account with page-creation permission

## Quick Start

```bash
# 1. Open Chrome with remote debugging and wait for manual login
python3 scripts/publish_confluence_html.py \
  --open-browser \
  --wait-login \
  --html "/mnt/d/Downloads/report.html" \
  --url "http://wiki.example.com/pages/createpage.action?spaceKey=SPC&fromPageId=123456" \
  --host-resolver "MAP wiki.example.com 10.0.0.1"

# 2. After review, publish directly
python3 scripts/publish_confluence_html.py \
  --publish \
  --html "/mnt/d/Downloads/report.html" \
  --url "http://wiki.example.com/pages/createpage.action?spaceKey=SPC&fromPageId=123456" \
  --host-resolver "MAP wiki.example.com 10.0.0.1"
```

## CLI Reference

| Flag | Default | Description |
|------|---------|-------------|
| `--html` | `/mnt/d/Downloads/report.html` | Local HTML file to publish |
| `--url` | Confluence createpage URL | Target create-page URL with `spaceKey` and `fromPageId` |
| `--port` | `9223` | Chrome remote debugging port |
| `--profile-dir` | `./chrome-profile-confluence` | Reusable Chrome user-data-dir (persists login) |
| `--title` | Auto from first `<h1>` or `<title>` | Override page title |
| `--host-resolver` | none | Chrome `--host-resolver-rules` for DNS override |
| `--open-browser` | off | Start a fresh Chrome window with CDP |
| `--wait-login` | off | Wait for manual Confluence login before proceeding |
| `--publish` | off | Click Publish after filling (uses REST API) |
| `--login-timeout` | `300` | Seconds to wait for manual login |

## How It Works

```
HTML File → BeautifulSoup simplify → Unicode sanitization → TinyMCE setContent → (optional) REST API publish
```

### HTML Simplification

The script strips scripts, styles, meta tags, SVGs, and decorative elements, then keeps only Confluence-safe tags: `h1`-`h4`, `p`, `ul`, `ol`, `li`, `strong`, `b`, `em`, `i`, `code`, `pre`, `blockquote`, `table`, `a`, `br`, `hr`. Container tags (`div`, `section`, `span`, etc.) are unwrapped to preserve text content.

### Unicode Sanitization

Old Confluence/Synchrony editors break on emoji, arrows, box-drawing characters, and private-use icon fonts. The script strips these ranges and replaces them with spaces to prevent editor corruption.

### Title Extraction

Priority: `--title` flag > first `<h1>` text > `<title>` tag text > `"Imported HTML Page"`.

### Publish Flow

Without `--publish`: fills title + body, enables the Publish button, and leaves the browser open for review.

With `--publish`: additionally calls `POST /rest/api/content` with the editor's HTML content, `spaceKey`, and `parentPageId`, then navigates to the created page.

## Inspecting Confluence Metadata

Use `scripts/check_confluence_meta.py` to dump AJS.Meta fields, forms, and script sources from the currently open Confluence page. Requires an active `agent-browser --cdp 9223` session.

```bash
python3 scripts/check_confluence_meta.py
```

## Reusable Login Profile

The `--profile-dir` flag (default `./chrome-profile-confluence`) stores the Chrome user-data-dir under a WSL path. On first run with `--open-browser --wait-login`, log in manually. Subsequent runs reuse the session without needing `--wait-login`.

## Confluence URL Format

The `--url` must point to a `createpage.action` endpoint with query parameters:

```
http://<confluence-host>/pages/createpage.action?spaceKey=<SPACE>&fromPageId=<PARENT_ID>
```

- `spaceKey`: target space (required for `--publish`)
- `fromPageId`: parent page ID (required for `--publish`)

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues: login loops, TinyMCE not ready, publish button disabled, Unicode errors, and Chrome CDP connection problems.
