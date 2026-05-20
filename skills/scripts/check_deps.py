#!/usr/bin/env python3
"""Check and optionally install Python dependencies from a requirements file."""

import argparse
import subprocess
import sys
from importlib.metadata import PackageNotFoundError, version as pkg_version
from pathlib import Path


def parse_requirements(req_path: Path) -> list[tuple[str, str]]:
    packages = []
    for line in req_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "==" in line:
            name, ver = line.split("==", 1)
            packages.append((name.strip(), ver.strip()))
        else:
            packages.append((line, ""))
    return packages


def check_missing(packages: list[tuple[str, str]]) -> list[tuple[str, str]]:
    missing = []
    for name, required_ver in packages:
        try:
            installed_ver = pkg_version(name)
            if required_ver and installed_ver != required_ver:
                missing.append((name, required_ver))
        except PackageNotFoundError:
            missing.append((name, required_ver))
    return missing


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("requirements", help="Requirements filename (relative to scripts/)")
    parser.add_argument("--fix", action="store_true", help="Auto-install missing packages")
    args = parser.parse_args()

    req_path = Path(__file__).parent / args.requirements
    if not req_path.exists():
        print(f"Requirements file not found: {req_path}", file=sys.stderr)
        sys.exit(1)

    packages = parse_requirements(req_path)
    missing = check_missing(packages)

    if not missing:
        sys.exit(0)

    if not args.fix:
        specs = [f"{n}=={v}" if v else n for n, v in missing]
        print("Missing packages:\n" + "\n".join(f"  - {s}" for s in specs))
        sys.exit(1)

    specs = [f"{n}=={v}" if v else n for n, v in missing]
    r = subprocess.run(
        [sys.executable, "-m", "pip", "install", *specs],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        print(f"pip install failed:\n{r.stderr}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
