#!/usr/bin/env python3
"""
Publish a local HTML file into a Confluence 6.x create-page editor via agent-browser.

Default behavior is conservative: fill title/body and leave the browser open for
manual review. Add --publish to click the Confluence Publish button.

Requires WSL + Windows Chrome + agent-browser (PowerShell callable).
"""

from __future__ import annotations

import argparse
import base64
import html
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
import time
from pathlib import Path
from typing import Iterable
from urllib.parse import parse_qs, urlparse


DEFAULT_URL = "http://wiki.example.com/pages/createpage.action?spaceKey=SPC&fromPageId=123456"
DEFAULT_HTML = "/mnt/d/Downloads/report.html"
DEFAULT_PORT = 9223


def run(cmd: list[str], *, input_text: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        cmd,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and proc.returncode != 0:
        joined = " ".join(cmd)
        raise SystemExit(f"Command failed: {joined}\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}")
    return proc


def ps(command: str, *, input_text: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(["powershell.exe", "-NoProfile", "-Command", command], input_text=input_text, check=check)


def agent(port: int, args: Iterable[str], *, input_text: str | None = None, check: bool = True) -> str:
    quoted = " ".join(powershell_quote(str(arg)) for arg in args)
    proc = ps(f"agent-browser --cdp {port} {quoted}", input_text=input_text, check=check)
    return proc.stdout.strip()


def powershell_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def wsl_to_windows_path(path: Path) -> str:
    proc = run(["wslpath", "-w", str(path)])
    return proc.stdout.strip()


def stop_chrome_on_port(port: int) -> None:
    script = rf"""
    $procs = Get-CimInstance Win32_Process -Filter "name = 'chrome.exe'" |
      Where-Object {{ $_.CommandLine -like '*--remote-debugging-port={port}*' }}
    foreach ($p in $procs) {{
      Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }}
    """
    ps(script, check=False)


def start_chrome(port: int, profile_dir: Path, host_resolver: str = "") -> None:
    profile_dir.mkdir(parents=True, exist_ok=True)
    win_profile = wsl_to_windows_path(profile_dir)
    stop_chrome_on_port(port)
    args = [
        f"--remote-debugging-port={port}",
        "--no-proxy-server",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-session-crashed-bubble",
        "--disable-features=DnsOverHttps,PasswordManagerEnableSaving",
        "--disable-save-password-bubble",
    ]
    if host_resolver:
        args.append(f"--host-resolver-rules={host_resolver}")
    args.extend([
        f"--user-data-dir={win_profile}",
        "about:blank",
    ])
    ps_args = ",".join(powershell_quote(arg) for arg in args)
    ps(f"Start-Process chrome.exe -ArgumentList {ps_args}")


def wait_for_agent(port: int, timeout: int) -> None:
    deadline = time.time() + timeout
    last = ""
    while time.time() < deadline:
        proc = ps(f"agent-browser --cdp {port} get url", check=False)
        if proc.returncode == 0 and proc.stdout.strip():
            return
        last = proc.stderr.strip() or proc.stdout.strip()
        time.sleep(1)
    raise SystemExit(f"Timed out waiting for Chrome/agent-browser on CDP port {port}. Last output: {last}")


def wait_until_not_login(port: int, timeout: int) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        url = agent(port, ["get", "url"], check=False)
        title = agent(port, ["get", "title"], check=False)
        if "login.action" not in url.lower() and "log in" not in title.lower() and "登录" not in title:
            return
        print("Still on login page. Please log in in the Chrome window...")
        time.sleep(3)
    raise SystemExit("Timed out waiting for login to complete.")


def open_target_page(port: int, url: str) -> None:
    agent(port, ["open", url])


def wait_for_editor(port: int, timeout: int) -> None:
    js = """
    (() => ({
      url: location.href,
      title: document.title,
      hasTitleInput: !!document.querySelector('#content-title, input[name="title"]'),
      hasTinyMce: !!(window.tinymce && (tinymce.get('wysiwygTextarea') || tinymce.activeEditor)),
      isLogin: location.href.indexOf('login.action') !== -1
    }))()
    """
    deadline = time.time() + timeout
    last = ""
    while time.time() < deadline:
        raw = agent(port, ["eval", "--stdin"], input_text=js, check=False)
        last = raw
        try:
            state = json.loads(raw)
        except json.JSONDecodeError:
            time.sleep(1)
            continue
        if state.get("isLogin"):
            raise SystemExit("Browser is on the login page. Log in first, then rerun the command.")
        if state.get("hasTitleInput") and state.get("hasTinyMce"):
            return
        time.sleep(1)
    raise SystemExit(f"Timed out waiting for Confluence editor. Last state: {last}")


def extract_title(source: str) -> str:
    h1 = re.search(r"<h1\b[^>]*>(.*?)</h1>", source, flags=re.I | re.S)
    if h1:
        return clean_text(h1.group(1))
    title = re.search(r"<title\b[^>]*>(.*?)</title>", source, flags=re.I | re.S)
    if title:
        return clean_text(title.group(1))
    return "Imported HTML Page"


def clean_text(fragment: str) -> str:
    fragment = re.sub(r"<[^>]+>", "", fragment)
    return strip_problem_unicode(html.unescape(re.sub(r"\s+", " ", fragment))).strip()


def strip_problem_unicode(value: str) -> str:
    """Remove glyphs that commonly break old Confluence/Synchrony editors."""
    ranges = (
        (0x200D, 0x200D),  # zero-width joiner
        (0x2190, 0x21FF),  # arrows
        (0x2300, 0x23FF),  # technical symbols
        (0x2460, 0x24FF),  # enclosed alphanumerics
        (0x2500, 0x257F),  # box drawing
        (0x25A0, 0x25FF),  # geometric shapes
        (0x2600, 0x27BF),  # misc symbols / dingbats
        (0xFE00, 0xFE0F),  # variation selectors
        (0x1F000, 0x1FAFF),  # emoji and pictographs
        (0xE000, 0xF8FF),  # private-use icon fonts
    )
    out: list[str] = []
    for ch in value:
        code = ord(ch)
        if any(start <= code <= end for start, end in ranges):
            if out and not out[-1].isspace():
                out.append(" ")
            continue
        out.append(ch)
    return re.sub(r"[ \t]{2,}", " ", "".join(out))


def simplify_html(source: str) -> str:
    try:
        from bs4 import BeautifulSoup
    except ImportError as exc:
        raise SystemExit("Missing Python package: beautifulsoup4. Install it or run in this WSL environment.") from exc

    soup = BeautifulSoup(strip_problem_unicode(source), "html.parser")
    for tag in soup(["script", "style", "meta", "link", "title"]):
        tag.decompose()

    root = soup.body or soup
    for svg in root.find_all("svg"):
        svg.decompose()

    allowed = {
        "h1", "h2", "h3", "h4", "p", "ul", "ol", "li",
        "strong", "b", "em", "i", "code", "pre", "blockquote",
        "table", "thead", "tbody", "tr", "th", "td",
        "br", "hr", "a",
    }
    unwrap_to_p = {"div", "section", "article", "main", "header", "footer", "span"}

    for tag in list(root.find_all(True)):
        if tag.name in allowed:
            attrs: dict[str, str] = {}
            if tag.name == "a" and tag.get("href"):
                attrs["href"] = strip_problem_unicode(tag["href"])
            tag.attrs = attrs
        elif tag.name in unwrap_to_p:
            tag.unwrap()
        else:
            tag.decompose()

    body_html = strip_problem_unicode("".join(str(child) for child in root.children))
    body_html = re.sub(r"\n{3,}", "\n\n", body_html).strip()
    return body_html or "<p></p>"


def build_injection_js(title: str, body_html: str, publish: bool, space_key: str, parent_page_id: str) -> str:
    payload = {
        "title": title,
        "bodyHtml": body_html,
        "publish": publish,
        "spaceKey": space_key,
        "parentPageId": parent_page_id,
    }
    encoded = base64.b64encode(json.dumps(payload, ensure_ascii=False).encode("utf-8")).decode("ascii")
    return textwrap.dedent(
        f"""
        (async () => {{
          const payload = JSON.parse(new TextDecoder('utf-8').decode(Uint8Array.from(atob('{encoded}'), c => c.charCodeAt(0))));

          const titleInput = document.querySelector('#content-title, input[name="title"]');
          if (!titleInput) throw new Error('Confluence title input not found');
          titleInput.focus();
          titleInput.value = payload.title;
          titleInput.dispatchEvent(new Event('input', {{ bubbles: true }}));
          titleInput.dispatchEvent(new Event('change', {{ bubbles: true }}));
          const titleWritten = document.querySelector('#titleWritten');
          if (titleWritten) titleWritten.value = 'true';

          const editor = window.tinymce && (tinymce.get('wysiwygTextarea') || tinymce.activeEditor);
          if (!editor) throw new Error('TinyMCE editor not found');
          editor.setContent(payload.bodyHtml);
          editor.save();
          if (typeof editor.setDirty === 'function') editor.setDirty(true);
          if (typeof editor.fire === 'function') {{
            editor.fire('change');
          }} else if (typeof editor.dispatch === 'function') {{
            editor.dispatch('change');
          }} else {{
            if (editor.onChange && typeof editor.onChange.dispatch === 'function') editor.onChange.dispatch(editor);
          }}
          if (typeof editor.nodeChanged === 'function') editor.nodeChanged();

          const textarea = document.querySelector('#wysiwygTextarea');
          if (textarea) {{
            textarea.value = editor.getContent();
            textarea.dispatchEvent(new Event('input', {{ bubbles: true }}));
            textarea.dispatchEvent(new Event('change', {{ bubbles: true }}));
          }}

          const publishButton = document.querySelector('#rte-button-publish');
          if (!publishButton) throw new Error('Publish button not found');
          publishButton.disabled = false;
          publishButton.removeAttribute('disabled');
          publishButton.setAttribute('aria-disabled', 'false');
          publishButton.classList.remove('disabled');

          const result = {{
            url: location.href,
            title: titleInput.value,
            bodyLength: editor.getContent().length,
            publishButtonDisabled: publishButton.disabled,
            published: false,
          }};

          if (payload.publish) {{
            const page = {{
              type: 'page',
              title: payload.title,
              space: {{ key: payload.spaceKey }},
              ancestors: [{{ id: payload.parentPageId }}],
              body: {{
                storage: {{
                  value: editor.getContent(),
                  representation: 'storage'
                }}
              }}
            }};
            const response = await fetch('/rest/api/content', {{
              method: 'POST',
              headers: {{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-Atlassian-Token': 'no-check'
              }},
              body: JSON.stringify(page),
              credentials: 'same-origin',
              redirect: 'follow'
            }});
            const responseText = await response.text();
            result.responseStatus = response.status;
            result.responseUrl = response.url;
            result.responseOk = response.ok;
            try {{
              result.responseJson = JSON.parse(responseText);
            }} catch (error) {{
              result.responseText = responseText.slice(0, 1000);
            }}
            const webui = result.responseJson && result.responseJson._links && result.responseJson._links.webui;
            if (response.ok && webui) {{
              window.onbeforeunload = null;
              location.href = webui;
            }}
            result.published = true;
          }}
          return result;
        }})()
        """
    ).strip()


def main() -> None:
    parser = argparse.ArgumentParser(description="Fill/publish a local HTML file into Confluence create-page editor.")
    parser.add_argument("--html", default=DEFAULT_HTML, help=f"Local HTML file. Default: {DEFAULT_HTML}")
    parser.add_argument("--url", default=DEFAULT_URL, help="Confluence createpage.action URL.")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"Chrome CDP port. Default: {DEFAULT_PORT}")
    parser.add_argument("--profile-dir", default="./chrome-profile-confluence", help="Windows Chrome user-data-dir, stored under WSL path.")
    parser.add_argument("--title", default="", help="Override page title. Default: first H1, then HTML title.")
    parser.add_argument("--host-resolver", default="", help="Chrome --host-resolver-rules value, e.g. 'MAP wiki.example.com 10.0.0.1'.")
    parser.add_argument("--open-browser", action="store_true", help="Start a Windows Chrome window with remote debugging.")
    parser.add_argument("--wait-login", action="store_true", help="Wait until the browser leaves Confluence login page.")
    parser.add_argument("--publish", action="store_true", help="Click Publish after filling. Without this, the page is left for review.")
    parser.add_argument("--login-timeout", type=int, default=300, help="Seconds to wait for manual login.")
    args = parser.parse_args()

    if not shutil.which("powershell.exe"):
        raise SystemExit("powershell.exe not found. Run this from WSL.")

    html_path = Path(args.html).expanduser()
    if not html_path.exists():
        raise SystemExit(f"HTML file not found: {html_path}")

    source = html_path.read_text(encoding="utf-8")
    title = args.title.strip() or extract_title(source)
    body_html = simplify_html(source)

    if args.open_browser:
        start_chrome(args.port, Path(args.profile_dir).expanduser(), args.host_resolver)
    wait_for_agent(args.port, timeout=45)

    open_target_page(args.port, args.url)

    current_url = agent(args.port, ["get", "url"], check=False)
    if "login.action" in current_url.lower():
        if not args.wait_login:
            raise SystemExit("Browser is on the login page. Re-run with --wait-login, then log in manually.")
        wait_until_not_login(args.port, args.login_timeout)
        open_target_page(args.port, args.url)

    wait_for_editor(args.port, timeout=60)

    query = parse_qs(urlparse(args.url).query)
    space_key = query.get("spaceKey", [""])[0]
    parent_page_id = query.get("fromPageId", [""])[0]
    if args.publish and (not space_key or not parent_page_id):
        raise SystemExit("Publish needs spaceKey and fromPageId in --url.")

    js = build_injection_js(title, body_html, args.publish, space_key, parent_page_id)
    result = agent(args.port, ["eval", "--stdin"], input_text=js)
    print(result)
    if args.publish:
        time.sleep(3)
        print(agent(args.port, ["get", "url"], check=False))
    else:
        print("Filled the page and left it open for review. Re-run with --publish to submit automatically.")


if __name__ == "__main__":
    main()
