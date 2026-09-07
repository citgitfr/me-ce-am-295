#!/usr/bin/env python3
"""Shared helper for the AWS Agent Toolkit setup scripts.

Stdlib only, compatible with Python 3.8+ (the stock macOS /usr/bin/python3 is
3.9), so it runs with whatever python3 is on the machine or with a python that
`uv` bootstraps on demand.

Subcommands:
  patch-mcp   Add AWS_MCP_PROXY_PROFILES=<profile> to every aws-mcp MCP entry
              the Agent Toolkit generated (Claude Code, Cursor, Gemini CLI,
              Kiro, Cline, Codex).
  write-rules Install the AWS rules file into each detected AI tool's project
              rules location (CLAUDE.md, AGENTS.md, .cursor/rules, .kiro/steering).
  check       Print the status of MCP entries, installed skills and rules files.
"""
import argparse
import json
import os
import re
import shutil
import sys
import time

MARK_START = "<!-- aws-agent-rules:start -->"
MARK_END = "<!-- aws-agent-rules:end -->"

# ---------------------------------------------------------------------------
# paths
# ---------------------------------------------------------------------------


def home(args):
    return os.path.expanduser(args.home or "~")


def json_mcp_configs(h):
    """Tool name -> JSON config file that holds an `mcpServers` map."""
    return {
        "Claude Code": os.path.join(h, ".claude.json"),
        "Cursor": os.path.join(h, ".cursor", "mcp.json"),
        "Gemini CLI": os.path.join(h, ".gemini", "settings.json"),
        "Kiro": os.path.join(h, ".kiro", "settings", "mcp.json"),
        "Cline": os.path.join(h, ".cline", "mcp.json"),
    }


def codex_config(h):
    return os.path.join(h, ".codex", "config.toml")


def backup(path):
    base = "%s.bak-%s" % (path, time.strftime("%Y%m%d-%H%M%S"))
    dst, n = base, 1
    while os.path.exists(dst):
        n += 1
        dst = "%s.%d" % (base, n)
    shutil.copy2(path, dst)
    return dst


def merge_profiles(existing, profile):
    """AWS_MCP_PROXY_PROFILES is a space separated list; keep others, add ours."""
    parts = [p for p in (existing or "").split() if p]
    if profile not in parts:
        parts.append(profile)
    return " ".join(parts)


# ---------------------------------------------------------------------------
# patch-mcp
# ---------------------------------------------------------------------------


def patch_json(path, profile, dry_run):
    if not os.path.exists(path):
        return "not found"
    with open(path, encoding="utf-8") as fh:
        raw = fh.read()
    try:
        data = json.loads(raw)
    except ValueError as exc:
        return "SKIPPED, not valid JSON (%s)" % exc
    servers = data.get("mcpServers") or {}
    entry = servers.get("aws-mcp")
    if not isinstance(entry, dict):
        return "no aws-mcp entry"
    env = entry.get("env")
    if not isinstance(env, dict):
        env = {}
        entry["env"] = env
    current = env.get("AWS_MCP_PROXY_PROFILES", "")
    merged = merge_profiles(current, profile)
    if merged == current:
        return "already set (%s)" % current
    env["AWS_MCP_PROXY_PROFILES"] = merged
    if dry_run:
        return "would set AWS_MCP_PROXY_PROFILES=%s" % merged
    bak = backup(path)
    indent = 2 if "\n  " in raw else 4
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=indent, ensure_ascii=False)
        fh.write("\n")
    return "set AWS_MCP_PROXY_PROFILES=%s (backup %s)" % (merged, os.path.basename(bak))


CODEX_SECTION = re.compile(r"^\[mcp_servers\.aws-mcp\]\s*$", re.M)
CODEX_ENV_SECTION = re.compile(r"^\[mcp_servers\.aws-mcp\.env\]\s*$", re.M)
CODEX_ENV_KEY = re.compile(r'^(AWS_MCP_PROXY_PROFILES[ \t]*=[ \t]*)"([^"]*)"[ \t]*$', re.M)
TOML_HEADER = re.compile(r"^\[", re.M)


def codex_env_section(src):
    """Return (start, end, block) of the [mcp_servers.aws-mcp.env] body, or None."""
    env_m = CODEX_ENV_SECTION.search(src)
    if not env_m:
        return None
    nxt = TOML_HEADER.search(src, env_m.end())
    end = nxt.start() if nxt else len(src)
    return env_m.end(), end, src[env_m.end():end]


def codex_current_profiles(src):
    sec = codex_env_section(src)
    if not sec:
        return None
    key_m = CODEX_ENV_KEY.search(sec[2])
    return key_m.group(2) if key_m else ""


def patch_codex(path, profile, dry_run):
    if not os.path.exists(path):
        return "not found"
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    if not CODEX_SECTION.search(src):
        return "no aws-mcp entry"
    if re.search(r"^\[mcp_servers\.aws-mcp\]\s*$(?:(?!^\[).)*^env\s*=", src, re.M | re.S):
        return "SKIPPED, aws-mcp uses an inline env table; add AWS_MCP_PROXY_PROFILES by hand"
    sec = codex_env_section(src)
    if sec:
        start, end, block = sec
        key_m = CODEX_ENV_KEY.search(block)
        current = key_m.group(2) if key_m else ""
        merged = merge_profiles(current, profile)
        if merged == current:
            return "already set (%s)" % current
        if key_m:
            new_block = CODEX_ENV_KEY.sub(lambda m: '%s"%s"' % (m.group(1), merged), block, count=1)
        else:
            new_block = block.rstrip("\n") + '\nAWS_MCP_PROXY_PROFILES = "%s"\n\n' % merged
        new_src = src[:start] + new_block + src[end:]
    else:
        sec = CODEX_SECTION.search(src)
        nxt = TOML_HEADER.search(src, sec.end())
        end = nxt.start() if nxt else len(src)
        body = src[sec.end():end].rstrip("\n")
        merged = profile
        insert = '%s\n\n[mcp_servers.aws-mcp.env]\nAWS_MCP_PROXY_PROFILES = "%s"\n\n' % (body, merged)
        new_src = src[:sec.end()] + insert + src[end:]
    if dry_run:
        return "would set AWS_MCP_PROXY_PROFILES=%s" % merged
    bak = backup(path)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new_src)
    return "set AWS_MCP_PROXY_PROFILES=%s (backup %s)" % (merged, os.path.basename(bak))


def cmd_patch_mcp(args):
    h = home(args)
    rows = []
    for tool, path in json_mcp_configs(h).items():
        rows.append((tool, path, patch_json(path, args.profile, args.dry_run)))
    rows.append(("Codex", codex_config(h), patch_codex(codex_config(h), args.profile, args.dry_run)))
    changed = 0
    for tool, path, status in rows:
        print("  %-11s %s: %s" % (tool, shorten(path, h), status))
        if status.startswith("set ") or status.startswith("would set"):
            changed += 1
    if not any(s.startswith(("set ", "already", "would")) for _, _, s in rows):
        print("  WARNING: no aws-mcp entry found in any config. Did 'aws configure agent-toolkit' run?")
        return 1
    return 0


# ---------------------------------------------------------------------------
# write-rules
# ---------------------------------------------------------------------------


def detect_tools(h):
    tools = []
    if os.path.isdir(os.path.join(h, ".claude")) or os.path.exists(os.path.join(h, ".claude.json")):
        tools.append("claude")
    if os.path.isdir(os.path.join(h, ".codex")) or os.path.isdir(os.path.join(h, ".gemini")):
        tools.append("codex")  # Codex and Gemini CLI both read AGENTS.md
    if os.path.isdir(os.path.join(h, ".cursor")):
        tools.append("cursor")
    if os.path.isdir(os.path.join(h, ".kiro")):
        tools.append("kiro")
    return tools or ["claude"]


def upsert_marked_block(path, body):
    """Insert or replace the marked AWS block; leave the rest of the file alone."""
    block = "%s\n%s\n%s\n" % (MARK_START, body.strip("\n"), MARK_END)
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        if MARK_START in src and MARK_END in src:
            pat = re.compile(re.escape(MARK_START) + r".*?" + re.escape(MARK_END) + r"\n?", re.S)
            new = pat.sub(lambda _m: block, src, count=1)
            if new == src:
                return "up to date"
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(new)
            return "updated"
        sep = "" if src.endswith("\n\n") else ("\n" if src.endswith("\n") else "\n\n")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(src + sep + block)
        return "appended"
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(block)
    return "created"


def write_whole_file(path, content):
    """Files the toolkit owns outright (Cursor .mdc needs frontmatter first, so no markers)."""
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            if fh.read() == content:
                return "up to date"
        status = "updated"
    else:
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        status = "created"
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)
    return status


OWNED_NOTE = "<!-- managed by setup/setup.sh, edit setup/rules/ upstream instead -->\n\n"


def cmd_write_rules(args):
    with open(args.rules_file, encoding="utf-8") as fh:
        body = fh.read()
    h = home(args)
    tools = detect_tools(h) if args.tools == "auto" else [t.strip() for t in args.tools.split(",") if t.strip()]
    d = args.dir
    # (tool, path, content, owned): owned files are rewritten whole; shared files get a marked block
    targets = []
    if "claude" in tools:
        targets.append(("Claude Code", os.path.join(d, "CLAUDE.md"), body, False))
    if "codex" in tools:
        targets.append(("Codex/Gemini", os.path.join(d, "AGENTS.md"), body, False))
    if "cursor" in tools:
        mdc = "---\ndescription: AWS guidance from the AWS Agent Toolkit\nalwaysApply: true\n---\n\n" + OWNED_NOTE + body
        targets.append(("Cursor", os.path.join(d, ".cursor", "rules", "aws-agent-rules.mdc"), mdc, True))
    if "kiro" in tools:
        targets.append(("Kiro", os.path.join(d, ".kiro", "steering", "aws-agent-rules.md"), OWNED_NOTE + body, True))
    for tool, path, content, owned in targets:
        status = write_whole_file(path, content) if owned else upsert_marked_block(path, content)
        print("  %-12s %s: %s" % (tool, os.path.relpath(path, d), status))
    return 0


# ---------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------


def shorten(path, h):
    return path.replace(h, "~", 1) if path.startswith(h) else path


def cmd_check(args):
    h = home(args)
    ok = True
    print("MCP server entries (aws-mcp):")
    found = False
    for tool, path in json_mcp_configs(h).items():
        if not os.path.exists(path):
            continue
        try:
            with open(path, encoding="utf-8") as fh:
                entry = (json.load(fh).get("mcpServers") or {}).get("aws-mcp")
        except ValueError:
            print("  %-11s %s: invalid JSON" % (tool, shorten(path, h)))
            ok = False
            continue
        if not entry:
            continue
        found = True
        val = (entry.get("env") or {}).get("AWS_MCP_PROXY_PROFILES", "")
        good = args.profile in val.split()
        ok = ok and good
        print("  %-11s %s: %s" % (tool, shorten(path, h), "profile %s wired" % args.profile if good else "MISSING AWS_MCP_PROXY_PROFILES=%s" % args.profile))
    cp = codex_config(h)
    if os.path.exists(cp):
        src = open(cp, encoding="utf-8").read()
        if CODEX_SECTION.search(src):
            found = True
            current = codex_current_profiles(src) or ""
            good = args.profile in current.split()
            ok = ok and good
            print("  %-11s %s: %s" % ("Codex", shorten(cp, h), "profile %s wired" % args.profile if good else "MISSING AWS_MCP_PROXY_PROFILES=%s" % args.profile))
    if not found:
        print("  none found (run the toolkit install step)")
        ok = False
    print("Installed AWS skills:")
    any_skills = False
    for tool, sd in (("Claude Code", ".claude/skills"), ("Codex/Gemini", ".agents/skills"), ("Cursor", ".cursor/skills"), ("Kiro", ".kiro/skills")):
        p = os.path.join(h, sd)
        if os.path.isdir(p):
            n = len([x for x in os.listdir(p) if x.startswith(("aws", "amazon", "launch-with", "signing-in"))])
            if n:
                any_skills = True
            print("  %-12s ~/%s: %d AWS skills" % (tool, sd, n))
    if not any_skills:
        print("  none found")
        ok = False
    print("Project rules files in %s:" % os.path.abspath(args.dir))
    for rel in ("CLAUDE.md", "AGENTS.md"):
        p = os.path.join(args.dir, rel)
        if os.path.exists(p):
            has = MARK_START in open(p, encoding="utf-8").read()
            print("  %-36s %s" % (rel, "has AWS rules block" if has else "present, no AWS rules block"))
    for rel in (".cursor/rules/aws-agent-rules.mdc", ".kiro/steering/aws-agent-rules.md"):
        if os.path.exists(os.path.join(args.dir, rel)):
            print("  %-36s present (managed by the toolkit)" % rel)
    return 0 if ok else 1


# ---------------------------------------------------------------------------


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--home", help="override HOME (used by tests)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("patch-mcp")
    p.add_argument("--profile", required=True)
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(fn=cmd_patch_mcp)

    w = sub.add_parser("write-rules")
    w.add_argument("--rules-file", required=True, help="path to the AWS rules markdown to install")
    w.add_argument("--dir", default=".", help="project root to write rules files into")
    w.add_argument("--tools", default="auto", help="auto or comma list of claude,codex,cursor,kiro")
    w.set_defaults(fn=cmd_write_rules)

    c = sub.add_parser("check")
    c.add_argument("--profile", required=True)
    c.add_argument("--dir", default=".")
    c.set_defaults(fn=cmd_check)

    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
