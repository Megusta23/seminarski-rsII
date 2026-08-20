#!/usr/bin/env python3
"""Lightweight offline checks used before the real .NET/Flutter toolchains run.

This does not replace dotnet build or flutter analyze. It catches malformed source,
missing local Dart imports, accidentally committed secrets, generated artifacts, and
several project-specific anti-patterns early.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent


def delimiter_error(path: Path) -> str | None:
    source = path.read_text(encoding="utf-8", errors="replace")
    stack: list[tuple[str, int, int]] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    openings = set(pairs.values())
    state = "code"
    quote = ""
    triple = False
    raw = False
    index = 0
    line = 1
    column = 1

    while index < len(source):
        char = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if char == "\n":
            line += 1
            column = 0

        if state == "line-comment":
            if char == "\n":
                state = "code"
        elif state == "block-comment":
            if char == "*" and following == "/":
                state = "code"
                index += 1
                column += 1
        elif state == "string":
            if triple:
                if source.startswith(quote * 3, index):
                    state = "code"
                    index += 2
                    column += 2
                elif char == "\\" and not raw:
                    index += 1
                    column += 1
            else:
                if char == quote:
                    state = "code"
                elif char == "\\" and not raw:
                    index += 1
                    column += 1
        else:
            if char == "/" and following == "/":
                state = "line-comment"
                index += 1
                column += 1
            elif char == "/" and following == "*":
                state = "block-comment"
                index += 1
                column += 1
            elif path.suffix == ".dart" and char in "rR" and following in "'\"":
                raw = True
                quote = following
                triple = source.startswith(following * 3, index + 1)
                state = "string"
                increment = 3 if triple else 1
                index += increment
                column += increment
            elif char in "'\"":
                raw = False
                quote = char
                triple = path.suffix == ".dart" and source.startswith(char * 3, index)
                state = "string"
                if triple:
                    index += 2
                    column += 2
            elif char in openings:
                stack.append((char, line, column))
            elif char in pairs:
                if not stack or stack[-1][0] != pairs[char]:
                    return f"{path.relative_to(ROOT)}:{line}:{column}: unmatched {char}"
                stack.pop()

        index += 1
        column += 1

    if state == "block-comment":
        return f"{path.relative_to(ROOT)}: unterminated block comment"
    if state == "string":
        return f"{path.relative_to(ROOT)}: unterminated string"
    if stack:
        return f"{path.relative_to(ROOT)}: unclosed delimiters {stack[-5:]}"
    return None


def source_files() -> list[Path]:
    patterns = (
        "src/**/*.cs",
        "tests/**/*.cs",
        "apps/**/*.dart",
        "packages/**/*.dart",
    )
    result: list[Path] = []
    for pattern in patterns:
        result.extend(ROOT.glob(pattern))
    return sorted(path for path in result if path.is_file())


def check_local_dart_imports(files: list[Path]) -> list[str]:
    package_roots = {
        "ladder_social_core": ROOT / "packages/ladder_social_core/lib",
        "ladder_social_mobile": ROOT / "apps/ladder_social_mobile/lib",
        "ladder_social_admin": ROOT / "apps/ladder_social_admin/lib",
    }
    pattern = re.compile(r"^(?:import|export)\s+'package:([^/]+)/([^']+)';", re.MULTILINE)
    errors: list[str] = []
    for path in files:
        if path.suffix != ".dart":
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in pattern.finditer(text):
            package, relative = match.groups()
            package_root = package_roots.get(package)
            if package_root is not None and not (package_root / relative).exists():
                errors.append(
                    f"{path.relative_to(ROOT)}: missing local package import {package}/{relative}"
                )
    return errors


def check_forbidden_paths() -> list[str]:
    forbidden_names = {".env", ".DS_Store"}
    forbidden_parts = {
        ".dart_tool",
        "bin",
        "obj",
        "build",
        "Pods",
        "DerivedData",
        ".gradle",
    }
    errors: list[str] = []
    for path in ROOT.rglob("*"):
        relative = path.relative_to(ROOT)
        if ".git" in relative.parts:
            continue
        if path.name in forbidden_names:
            errors.append(f"Forbidden local file is present: {relative}")
        if any(part in forbidden_parts for part in relative.parts):
            # Generated folders can exist locally after a build; only warn when tracked.
            continue
    return errors


def check_tracked_secrets() -> list[str]:
    errors: list[str] = []
    git_index = ROOT / ".git/index"
    if not git_index.exists():
        return errors
    import subprocess

    completed = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=False,
        text=True,
        capture_output=True,
    )
    if completed.returncode != 0:
        return errors
    tracked = completed.stdout.splitlines()
    for item in tracked:
        name = Path(item).name
        if name == ".env" or name.endswith(".p12") or name.endswith(".pem"):
            errors.append(f"Potential secret/signing file is tracked: {item}")
    return errors


def check_antipatterns(files: list[Path]) -> list[str]:
    checks = {
        r"\bConsole\.WriteLine\s*\(": "Use ILogger<T> instead of Console.WriteLine.",
        r"\.GetAwaiter\(\)\.GetResult\(\)": "Synchronous async blocking is not allowed.",
        r"\.Wait\s*\(": "Synchronous async blocking is not allowed.",
        r"Thread\.Sleep\s*\(": "Use await Task.Delay instead of Thread.Sleep.",
        r"throw\s+new\s+NotImplementedException": "Incomplete methods are not allowed.",
        r"new\s+HttpClient\s*\(": "Use IHttpClientFactory instead of new HttpClient().",
    }
    errors: list[str] = []
    for path in files:
        if path.suffix != ".cs":
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for pattern, message in checks.items():
            for match in re.finditer(pattern, text):
                line = text.count("\n", 0, match.start()) + 1
                errors.append(f"{path.relative_to(ROOT)}:{line}: {message}")
    return errors


def main() -> int:
    files = source_files()
    errors: list[str] = []
    for path in files:
        error = delimiter_error(path)
        if error:
            errors.append(error)
    errors.extend(check_local_dart_imports(files))
    errors.extend(check_tracked_secrets())
    errors.extend(check_antipatterns(files))

    if errors:
        print("Static source checks failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Static source checks passed for {len(files)} C#/Dart files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
