#!/usr/bin/env python3
"""
Auto-fix script for Flutter/Dart common build errors.
Runs before build to patch known issues.
"""
import os
import re
import sys
import subprocess
from pathlib import Path

ROOT = Path.cwd()
MAIN_DART = ROOT / "lib" / "main.dart"
PUBSPEC = ROOT / "pubspec.yaml"


def log(msg):
    print(f"\033[1;36m[auto-fix]\033[0m {msg}")


def warn(msg):
    print(f"\033[1;33m[auto-fix]\033[0m {msg}")


def ok(msg):
    print(f"\033[1;32m[auto-fix]\033[0m {msg}")


def fix_regex_patterns(content: str) -> tuple[str, bool]:
    """Fix common raw-string regex escaping issues in Dart."""
    changed = False

    # Fix Dart string pattern
    broken1 = '''RegExp(r"'(?:[^'\\\\]|\\\\.)*'|\\"(?:[^\\"\\\\]|\\\\.)*\\"")'''
    fixed1 = '''RegExp("'(?:[^'\\\\\\\\]|\\\\\\\\.)*'|\\"(?:[^\\"\\\\\\\\]|\\\\\\\\.)*\\"")'''
    if broken1 in content:
        content = content.replace(broken1, fixed1)
        changed = True
        ok("Fixed Dart string regex pattern")

    # Fix YAML string pattern
    broken2 = '''RegExp(r"'[^']*'|\\"[^\\"]*\\"")'''
    fixed2 = '''RegExp("'[^']*'|\\"[^\\"]*\\"")'''
    if broken2 in content:
        content = content.replace(broken2, fixed2)
        changed = True
        ok("Fixed YAML string regex pattern")

    return content, changed


def fix_const_richtext(content: str) -> tuple[str, bool]:
    """Fix `const RichText(` -> `RichText(` with `const TextSpan(`."""
    changed = False

    pattern = re.compile(r'const RichText\(\s*text:\s*TextSpan\(')
    if pattern.search(content):
        content = pattern.sub('RichText(\n                      text: const TextSpan(', content)
        changed = True
        ok("Fixed const RichText issue")

    return content, changed


def fix_dart_file(path: Path) -> bool:
    if not path.exists():
        warn(f"File not found: {path}")
        return False

    src = path.read_text(encoding="utf-8")
    orig = src

    src, c1 = fix_regex_patterns(src)
    src, c2 = fix_const_richtext(src)

    if src != orig:
        path.write_text(src, encoding="utf-8")
        return True
    return False


def run(cmd, check=False):
    log(f"$ {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    result = subprocess.run(
        cmd, shell=isinstance(cmd, str),
        capture_output=True, text=True,
    )
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}")
    return result


def clean_gradle_cache():
    """Remove problematic Gradle cache entries if any."""
    for d in [
        ROOT / "android" / ".gradle",
        ROOT / "build",
        ROOT / ".dart_tool",
    ]:
        if d.exists():
            log(f"Removing {d}")
            subprocess.run(["rm", "-rf", str(d)], check=False)


def main():
    log("Starting auto-fix...")

    # 1. Fix main.dart
    if fix_dart_file(MAIN_DART):
        ok("main.dart patched")
    else:
        log("main.dart: no changes needed")

    # 2. Clean problematic caches
    clean_gradle_cache()

    # 3. flutter clean
    run(["flutter", "clean"])
    run(["flutter", "pub", "get"], check=True)

    ok("Auto-fix complete ✅")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        warn(f"Auto-fix failed: {e}")
        sys.exit(1)
