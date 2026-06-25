#!/usr/bin/env python3
"""Inspect Confluence page metadata via agent-browser CDP session."""

import subprocess

js = r"""
(() => ({
  baseUrl: window.AJS && AJS.Meta && AJS.Meta.get('base-url'),
  contextPath: window.AJS && AJS.Meta && AJS.Meta.get('context-path'),
  remoteUser: window.AJS && AJS.Meta && AJS.Meta.get('remote-user'),
  restBase: window.AJS && AJS.Meta && AJS.Meta.get('rest-base-url'),
  meta: window.AJS && AJS.Meta ? ['base-url','context-path','content-id','page-id','space-key','latest-published-page-title'].reduce((a,k)=>(a[k]=AJS.Meta.get(k),a),{}) : null,
  forms: Array.from(document.querySelectorAll('form')).map(f => ({ id: f.id, action: f.action, method: f.method })),
  scripts: Array.from(document.querySelectorAll('script[src]')).slice(0,12).map(e => e.src)
}))()
"""

p = subprocess.run(
    ["powershell.exe", "-NoProfile", "-Command", "agent-browser --cdp 9223 eval --stdin"],
    input=js,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
print(p.stdout)
print(p.stderr)
raise SystemExit(p.returncode)
