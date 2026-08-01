#!/usr/bin/env python3
"""Sync the Kratos Claude Code plugin into this opencode config.

Re-runnable. Reads the newest installed plugin version out of the Claude Code
plugin cache and regenerates opencode-native agents, commands, skills and the
shared resource tree. Every generated file is prefixed `kratos` and is wiped
before each run, so a plugin upgrade is just:

    python scripts/sync-kratos.py

Nothing outside the kratos* namespace is touched.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

# --- configuration ---------------------------------------------------------

OPENCODE = Path(__file__).resolve().parent.parent
PLUGIN_CACHE = Path.home() / ".claude/plugins/cache/lizard-plugins/kratos"

# Destination for the plugin's shared resource tree. Agent/command bodies refer
# to it as <KRATOS_ROOT>; the rewriter substitutes this absolute path.
KRATOS_ROOT = OPENCODE / "kratos"

# Directories copied verbatim from the plugin into KRATOS_ROOT.
# `hooks` and `agents` are required at runtime, not just for reference: command
# files shell out to `hooks/launch.cjs agent load <god>`, which reads
# `agents/<god>.md` and resolves the kratos binary (falling back to
# ~/.kratos/bin) to expand protocol sections.
RESOURCE_DIRS = [
    "agents",
    "hooks",
    "pipeline",
    "modes",
    "rules",
    "templates",
    "references",
    "docs",
    "command-mode-suffix",
]

# Claude Code model tier -> opencode provider/model. Bump these when the
# models declared in opencode.json change.
MODELS = {
    "opus": "anthropic/claude-opus-4-5-20251101",
    "sonnet": "anthropic/claude-sonnet-4-5-20250929",
    "haiku": "anthropic/claude-haiku-4-5-20251001",
}

# Every tool opencode knows about. Agents get an explicit true/false for each
# so the plugin's tool restrictions actually bind instead of silently
# defaulting to "everything enabled".
ALL_TOOLS = [
    "read", "write", "edit", "patch", "bash",
    "glob", "grep", "list", "webfetch", "task",
    "todowrite", "todoread",
]

# Claude Code tool name -> opencode tool name(s). Tools with no opencode
# equivalent map to () and are dropped.
TOOL_MAP = {
    "Read": ("read",),
    "Write": ("write",),
    "Edit": ("edit", "patch"),
    "Glob": ("glob", "list"),
    "Grep": ("grep",),
    "Bash": ("bash",),
    "Task": ("task",),
    "WebFetch": ("webfetch",),
    "WebSearch": ("webfetch",),  # opencode has no separate search tool
    "TaskCreate": ("todowrite", "todoread"),
    "TaskUpdate": ("todowrite", "todoread"),
    "TaskList": ("todowrite", "todoread"),
    "AskUserQuestion": (),  # opencode agents ask in plain text
    "NotebookEdit": (),
}

# --- frontmatter -----------------------------------------------------------

FM_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n?", re.DOTALL)


def split_frontmatter(text: str) -> tuple[dict[str, str], str]:
    """Return (frontmatter, body). Only the flat scalar keys we need are parsed
    -- values may be folded (`>-`) or literal (`|`) blocks."""
    m = FM_RE.match(text)
    if not m:
        return {}, text
    fm: dict[str, str] = {}
    key = None
    for line in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if km:
            key, val = km.group(1), km.group(2).strip()
            if val in (">", ">-", "|", "|-"):
                fm[key] = ""  # continuation lines collected below
            else:
                fm[key] = val.strip("\"'")
        elif key and line.strip():
            fm[key] = (fm[key] + " " + line.strip()).strip()
    return fm, text[m.end():]


def yaml_scalar(value: str) -> str:
    """Quote a value so it survives as a single YAML line."""
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


# --- body rewriting --------------------------------------------------------

ROOT_STR = str(KRATOS_ROOT).replace("\\", "/")
CMD_DIR_STR = str(OPENCODE / "commands").replace("\\", "/")

# `!echo "KRATOS_ROOT=${CLAUDE_PLUGIN_ROOT}"` is a Claude Code command-file
# shell escape whose only job was to reveal the plugin root at runtime. Every
# path is baked in below, so the line is dropped outright.
ECHO_RE = re.compile(r'^!echo "KRATOS_ROOT=\$\{CLAUDE_PLUGIN_ROOT\}"\s*\r?\n', re.M)

# ...which leaves prose telling the agent to resolve <KRATOS_ROOT> itself. That
# instruction is now false and actively misleading, so it is replaced.
RESOLVE_PROSE_RE = re.compile(
    r"^.*KRATOS_ROOT.*?[Ss]ubstitute it for every.*$", re.M
)
RESOLVE_NOTE = "All Kratos resource paths in this file are already absolute."

SKILL_RE = re.compile(r'Skill\(skill:\s*"kratos:([a-z0-9<>_-]+)"\)')

# `<KRATOS_ROOT>/commands/<x>.md` refers to a Claude-format command file. The
# opencode translation of it lives in the config's own commands dir.
ROOT_CMD_RE = re.compile(r"<KRATOS_ROOT>/commands/([a-z0-9-]+)\.md")


def rewrite_body(body: str) -> str:
    body = ECHO_RE.sub("", body)
    body = RESOLVE_PROSE_RE.sub(RESOLVE_NOTE, body)

    # opencode cannot invoke a skill mid-turn -- the command files are plain
    # markdown, so point at them by path and instruct the model to follow them.
    # The replacement must stay backtick-free: these calls often sit inside an
    # existing code span, and nesting backticks breaks the markdown.
    body = SKILL_RE.sub(
        lambda m: f"/kratos-{m.group(1)} -- read {CMD_DIR_STR}/"
                  f"kratos-{m.group(1)}.md and follow it",
        body,
    )

    # Remaining `kratos:<name>` refs are agent identifiers (Task subagent_type,
    # agent tables). opencode namespaces with a hyphen.
    body = re.sub(r"kratos:([a-z][a-z0-9-]*)", r"kratos-\1", body)

    body = ROOT_CMD_RE.sub(rf"{CMD_DIR_STR}/kratos-\1.md", body)
    body = body.replace("<KRATOS_ROOT>", ROOT_STR)

    # Command files shell out through the plugin root env var, which opencode
    # never sets. Point it at the copied tree (`${VAR:-}` default form too).
    body = re.sub(r"\$\{CLAUDE_PLUGIN_ROOT(?::-)?\}", ROOT_STR, body)
    return body


# --- generators ------------------------------------------------------------

def convert_agent(src: Path, dst_dir: Path) -> str:
    fm, body = split_frontmatter(src.read_text(encoding="utf-8"))
    name = fm.get("name") or src.stem

    granted: set[str] = set()
    for tool in (t.strip() for t in fm.get("tools", "").split(",") if t.strip()):
        granted.update(TOOL_MAP.get(tool, ()))

    lines = [
        "---",
        f"description: {yaml_scalar(fm.get('description', name))}",
        "mode: subagent",
        f"model: {MODELS[fm.get('model', 'sonnet')]}",
        "tools:",
    ]
    lines += [f"  {t}: {'true' if t in granted else 'false'}" for t in ALL_TOOLS]
    lines += ["---", ""]

    out = dst_dir / f"kratos-{name}.md"
    out.write_text("\n".join(lines) + rewrite_body(body), encoding="utf-8")
    return out.name


def convert_command(src: Path, dst_dir: Path) -> str:
    fm, body = split_frontmatter(src.read_text(encoding="utf-8"))
    name = fm.get("name") or src.stem
    header = f"---\ndescription: {yaml_scalar(fm.get('description', name))}\n---\n"
    out = dst_dir / f"kratos-{name}.md"
    out.write_text(header + rewrite_body(body), encoding="utf-8")
    return out.name


def convert_skill(src: Path, dst_dir: Path, slug: str) -> str:
    fm, body = split_frontmatter(src.read_text(encoding="utf-8"))
    header = (
        "---\n"
        f"name: {slug}\n"
        f"description: {yaml_scalar(fm.get('description', slug))}\n"
        "---\n"
    )
    out = dst_dir / slug / "SKILL.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(header + rewrite_body(body), encoding="utf-8")
    return f"{slug}/SKILL.md"


def build_primary_agent(skill_src: Path, dst_dir: Path) -> str:
    """The plugin has no orchestrator *agent* -- routing lives in skills/auto.
    opencode's agent switcher wants a primary entry, so the same router body is
    also emitted as `kratos`."""
    fm, body = split_frontmatter(skill_src.read_text(encoding="utf-8"))
    lines = [
        "---",
        'description: "Kratos - God of War orchestrator. Routes to the right god-agent '
        'or pipeline stage."',
        "mode: primary",
        f"model: {MODELS['opus']}",
        "tools:",
    ]
    lines += [f"  {t}: true" for t in ALL_TOOLS]
    lines += ["---", ""]
    out = dst_dir / "kratos.md"
    out.write_text("\n".join(lines) + rewrite_body(body), encoding="utf-8")
    return out.name


BEGIN = "<!-- BEGIN kratos-sync -->"
END = "<!-- END kratos-sync -->"


def write_activation_rule(version: str) -> str:
    """Claude Code fires the Kratos skill from a UserPromptSubmit hook. opencode
    has no prompt hook, so the keyword rule has to be a standing instruction.
    Written as a managed block -- anything else in AGENTS.md is preserved."""
    gods = ("Athena, Ares, Metis, Apollo, Artemis, Hermes, Hephaestus, Daedalus, "
            "Clio, Mimir, Hades, Odysseus, Prometheus, Themis, Nemesis, Cassandra, "
            "Hera, Ananke, Iris")
    block = f"""{BEGIN}
<!-- generated by scripts/sync-kratos.py from kratos {version} -- edits are overwritten -->

## Kratos Auto-Activation

When the user mentions **"Kratos"**, or addresses a god-agent by name ({gods}),
or says "continue"/"next stage" during an active pipeline:

1. Read `{str(OPENCODE / "skills/kratos-auto/SKILL.md").replace(chr(92), "/")}` first.
2. Follow its routing table to the matching `/kratos-*` command file under
   `{CMD_DIR_STR}/`, and follow that file's instructions exactly.

Do not answer a Kratos-addressed request directly and do not improvise the
pipeline -- the command files own all routing, gating, and agent-spawn detail.
Spawn gods with the task tool using their opencode names (`kratos-ares`,
`kratos-athena`, ...), never `kratos:<name>`.

Kratos resources live in `{ROOT_STR}` (pipeline/, modes/, rules/, templates/,
references/). Re-sync after a plugin upgrade with `python scripts/sync-kratos.py`.
{END}"""

    path = OPENCODE / "AGENTS.md"
    if path.exists():
        existing = path.read_text(encoding="utf-8")
        if BEGIN in existing and END in existing:
            new = re.sub(
                re.escape(BEGIN) + r".*?" + re.escape(END), block, existing, flags=re.DOTALL
            )
            action = "updated block in"
        else:
            new = existing.rstrip() + "\n\n" + block + "\n"
            action = "appended block to"
    else:
        new = "# Global opencode instructions\n\n" + block + "\n"
        action = "created"
    path.write_text(new, encoding="utf-8")
    return f"{action} AGENTS.md"


# --- housekeeping ----------------------------------------------------------

def newest_plugin_version() -> Path:
    if not PLUGIN_CACHE.is_dir():
        sys.exit(f"plugin cache not found: {PLUGIN_CACHE}")

    def key(p: Path) -> tuple[int, ...]:
        return tuple(int(n) for n in re.findall(r"\d+", p.name)) or (0,)

    versions = sorted((p for p in PLUGIN_CACHE.iterdir() if p.is_dir()), key=key)
    if not versions:
        sys.exit(f"no kratos versions installed under {PLUGIN_CACHE}")
    return versions[-1]


def sweep(dry_run: bool) -> list[str]:
    """Delete every previously generated kratos artifact so renamed or removed
    upstream files do not linger."""
    removed = []
    for pattern in ("agents/kratos*.md", "commands/kratos*.md"):
        for p in OPENCODE.glob(pattern):
            removed.append(str(p.relative_to(OPENCODE)))
            if not dry_run:
                p.unlink()
    for p in OPENCODE.glob("skills/kratos*"):
        if p.is_dir():
            removed.append(str(p.relative_to(OPENCODE)) + "/")
            if not dry_run:
                shutil.rmtree(p)
    if KRATOS_ROOT.exists():
        removed.append(str(KRATOS_ROOT.relative_to(OPENCODE)) + "/")
        if not dry_run:
            shutil.rmtree(KRATOS_ROOT)
    return removed


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--plugin", type=Path, help="plugin version dir (default: newest)")
    ap.add_argument("--dry-run", action="store_true", help="report without writing")
    args = ap.parse_args()

    plugin = args.plugin or newest_plugin_version()
    if not (plugin / "agents").is_dir():
        sys.exit(f"not a kratos plugin dir: {plugin}")

    print(f"source : {plugin}")
    print(f"target : {OPENCODE}")

    removed = sweep(args.dry_run)
    print(f"\nremoved {len(removed)} stale artifact(s)")
    for r in sorted(removed):
        print(f"  - {r}")

    if args.dry_run:
        print("\ndry run -- nothing written")
        return

    # shared resources
    KRATOS_ROOT.mkdir(parents=True, exist_ok=True)
    copied = []
    for d in RESOURCE_DIRS:
        src = plugin / d
        if src.is_dir():
            shutil.copytree(src, KRATOS_ROOT / d)
            copied.append(d)
    (KRATOS_ROOT / "VERSION").write_text(plugin.name + "\n", encoding="utf-8")
    print(f"\nresources -> kratos/: {', '.join(copied)}")

    agents_dir = OPENCODE / "agents"
    commands_dir = OPENCODE / "commands"
    skills_dir = OPENCODE / "skills"
    for d in (agents_dir, commands_dir, skills_dir):
        d.mkdir(parents=True, exist_ok=True)

    agents = [convert_agent(f, agents_dir) for f in sorted((plugin / "agents").glob("*.md"))]
    print(f"\nagents ({len(agents)}): {', '.join(a[:-3] for a in agents)}")

    commands = [convert_command(f, commands_dir) for f in sorted((plugin / "commands").glob("*.md"))]
    print(f"\ncommands ({len(commands)}): {', '.join(c[:-3] for c in commands)}")

    skills = []
    for skill_dir in sorted((plugin / "skills").iterdir()):
        skill_md = skill_dir / "SKILL.md"
        if skill_md.is_file():
            skills.append(convert_skill(skill_md, skills_dir, f"kratos-{skill_dir.name}"))
    print(f"\nskills ({len(skills)}): {', '.join(skills)}")

    auto = plugin / "skills/auto/SKILL.md"
    if auto.is_file():
        print(f"\nprimary agent: {build_primary_agent(auto, agents_dir)}")

    print(f"\nactivation: {write_activation_rule(plugin.name)}")
    print(f"\nsynced kratos {plugin.name}")


if __name__ == "__main__":
    main()
