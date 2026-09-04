#!/usr/bin/env python3
"""HomeVault P15 CI/CD hardening helpers.

This script intentionally never prints secret values. It provides small,
portable gates used by GitHub Actions and by local P15 validation.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
DEV_FIREBASE_PROJECT = "homevault-aamir-india-1701"
PACKAGE_ID = "com.amuaamir.homevault"
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")
FLUTTER_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
RELEASE_RE = re.compile(r"^R\d+$")

SENSITIVE_TRACKED_PATTERNS = [
    re.compile(r"(^|/)android/key\.properties$", re.I),
    re.compile(r"\.(?:jks|keystore|p12|pfx)$", re.I),
    re.compile(r"(^|/)lib/firebase_options\.dart$", re.I),
    re.compile(r"(^|/)android/app/google-services\.json$", re.I),
    re.compile(r"(?:service[-_]?account|firebase-admin|adminsdk).*\.json$", re.I),
]


def run(cmd: list[str], *, check: bool = True, cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=check)


def fail(message: str) -> "NoReturn":
    if os.getenv("GITHUB_ACTIONS") == "true":
        print(f"::error::{message}")
    else:
        print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def info(message: str) -> None:
    print(message)


def read_source_metadata() -> dict[str, object]:
    pubspec_path = ROOT / "pubspec.yaml"
    build_info_path = ROOT / "lib/core/app_build_info.dart"
    if not pubspec_path.is_file() or not build_info_path.is_file():
        fail("Run this command from a HomeVault repository containing pubspec.yaml and lib/core/app_build_info.dart.")

    pubspec = pubspec_path.read_text(encoding="utf-8")
    match = re.search(r"(?m)^version:\s*([^+\s]+)\+(\d+)\s*$", pubspec)
    if not match:
        fail("pubspec.yaml must contain version: <semantic-version>+<numeric-build>.")
    version = match.group(1)
    build = int(match.group(2))
    if not SEMVER_RE.fullmatch(version):
        fail(f"pubspec semantic version is invalid: {version}")
    if build <= 0:
        fail("pubspec build number must be a positive integer.")

    build_info = build_info_path.read_text(encoding="utf-8")
    def constant(name: str) -> str:
        m = re.search(rf"static const String {re.escape(name)} = '([^']*)';", build_info)
        if not m:
            fail(f"AppBuildInfo.{name} was not found.")
        return m.group(1)

    app_version = constant("version")
    app_build = constant("buildNumber")
    release = constant("releaseNumber")
    if app_version != version:
        fail(f"AppBuildInfo.version ({app_version}) does not match pubspec version ({version}).")
    if app_build != str(build):
        fail(f"AppBuildInfo.buildNumber ({app_build}) does not match pubspec build number ({build}).")
    if not RELEASE_RE.fullmatch(release):
        fail(f"AppBuildInfo.releaseNumber must use RNN format; found {release}.")

    return {"version": version, "build": build, "release": release}


def validate_flutter_version() -> None:
    value = os.getenv("FLUTTER_VERSION", "").strip()
    if not value:
        fail("Repository variable FLUTTER_VERSION is missing.")
    if not FLUTTER_VERSION_RE.fullmatch(value):
        fail("FLUTTER_VERSION must be an exact x.y.z version (for example 3.44.0), not stable/latest/a range.")
    info(f"FLUTTER_VERSION format: PASS ({value})")


def tracked_files() -> list[str]:
    try:
        out = run(["git", "ls-files"]).stdout
    except Exception as exc:
        fail(f"Unable to inspect Git tracked files: {exc}")
    return [line.strip().replace("\\", "/") for line in out.splitlines() if line.strip()]


def validate_hygiene() -> None:
    offenders: list[str] = []
    for path in tracked_files():
        if any(pattern.search(path) for pattern in SENSITIVE_TRACKED_PATTERNS):
            offenders.append(path)
    if offenders:
        fail("Sensitive/generated release files must not be tracked by Git: " + ", ".join(sorted(offenders)))
    info("Tracked source secret hygiene: PASS")


def validate_lock() -> None:
    lock = ROOT / "pubspec.lock"
    if not lock.is_file():
        fail("pubspec.lock is required for deterministic HomeVault builds.")
    tracked = run(["git", "ls-files", "--error-unmatch", "pubspec.lock"], check=False)
    if tracked.returncode != 0:
        fail("pubspec.lock must be tracked in Git.")
    diff = run(["git", "diff", "--", "pubspec.lock"], check=False)
    staged = run(["git", "diff", "--cached", "--", "pubspec.lock"], check=False)
    if diff.stdout.strip() or staged.stdout.strip():
        fail("pubspec.lock changed during CI. Dependency resolution must be deterministic; commit intended lockfile changes explicitly.")
    info("pubspec.lock reproducibility: PASS")


def require_names(names: Iterable[str], label: str) -> None:
    missing = [name for name in names if not os.getenv(name, "").strip()]
    if missing:
        fail(f"Missing required {label}: " + ", ".join(missing))
    for name in names:
        info(f"{label} {name}: present")


def validate_ci(mode: str, prerelease: bool) -> None:
    validate_flutter_version()
    validate_hygiene()
    read_source_metadata()
    require_names(["FIREBASE_OPTIONS_DART_BASE64"], "secret") if mode == "development" else None
    if mode == "developer-release":
        require_names([
            "FIREBASE_OPTIONS_DART_BASE64", "GOOGLE_SERVICES_JSON_BASE64",
            "ANDROID_KEYSTORE_BASE64", "ANDROID_STORE_PASSWORD", "ANDROID_KEY_PASSWORD",
            "ANDROID_KEY_ALIAS", "GDRIVE_RCLONE_CONFIG_BASE64",
        ], "secret")
    elif mode == "manual-release":
        require_names([
            "ANDROID_KEYSTORE_BASE64", "ANDROID_STORE_PASSWORD", "ANDROID_KEY_PASSWORD",
            "ANDROID_KEY_ALIAS", "GDRIVE_RCLONE_CONFIG_BASE64",
        ], "secret")
        if prerelease:
            require_names(["DEV_FIREBASE_OPTIONS_DART_BASE64", "DEV_GOOGLE_SERVICES_JSON_BASE64"], "development Firebase secret")
        else:
            require_names(["PROD_FIREBASE_OPTIONS_DART_BASE64", "PROD_GOOGLE_SERVICES_JSON_BASE64"], "production Firebase secret")
            require_names(["PRODUCTION_FIREBASE_PROJECT_ID"], "repository variable")
            if os.getenv("PRODUCTION_FIREBASE_PROJECT_ID") == DEV_FIREBASE_PROJECT:
                fail("Production Firebase cannot use the HomeVault development Firebase project.")
    info(f"CI configuration ({mode}): PASS")


def locate_apksigner() -> str | None:
    direct = shutil.which("apksigner")
    if direct:
        return direct
    android_home = os.getenv("ANDROID_HOME") or os.getenv("ANDROID_SDK_ROOT")
    if android_home:
        candidates = sorted(Path(android_home, "build-tools").glob("*/apksigner"), reverse=True)
        if candidates:
            return str(candidates[0])
    return None


def locate_apkanalyzer() -> str | None:
    direct = shutil.which("apkanalyzer")
    if direct:
        return direct
    android_home = os.getenv("ANDROID_HOME") or os.getenv("ANDROID_SDK_ROOT")
    if android_home:
        cmdline = Path(android_home, "cmdline-tools", "latest", "bin", "apkanalyzer")
        if cmdline.exists():
            return str(cmdline)
    return None


def verify_artifact(path: Path, kind: str, expected_version: str | None, expected_build: str | None) -> None:
    if not path.is_file() or path.stat().st_size <= 0:
        fail(f"{kind.upper()} artifact is missing or empty: {path}")
    if kind == "apk":
        signer = locate_apksigner()
        if not signer:
            fail("apksigner was not found in the Android SDK; signed APK verification is mandatory.")
        result = run([signer, "verify", "--verbose", "--print-certs", str(path)], check=False)
        if result.returncode != 0:
            fail("APK signature verification failed.")
        info("APK signature verification: PASS")

        analyzer = locate_apkanalyzer()
        if analyzer:
            package_result = run([analyzer, "manifest", "application-id", str(path)], check=False)
            if package_result.returncode == 0:
                actual = package_result.stdout.strip()
                if actual != PACKAGE_ID:
                    fail(f"APK package ID mismatch: expected {PACKAGE_ID}, found {actual}")
                info(f"APK package ID: PASS ({actual})")
            if expected_version:
                vr = run([analyzer, "manifest", "version-name", str(path)], check=False)
                if vr.returncode == 0 and vr.stdout.strip() != expected_version:
                    fail(f"APK version-name mismatch: expected {expected_version}, found {vr.stdout.strip()}")
            if expected_build:
                br = run([analyzer, "manifest", "version-code", str(path)], check=False)
                if br.returncode == 0 and br.stdout.strip() != str(expected_build):
                    fail(f"APK version-code mismatch: expected {expected_build}, found {br.stdout.strip()}")
        else:
            info("apkanalyzer not available; package/version metadata check skipped after successful APK signature verification.")
    elif kind == "aab":
        signer = shutil.which("jarsigner")
        if not signer:
            fail("jarsigner was not found; signed AAB verification is mandatory for stable releases.")
        result = run([signer, "-verify", "-strict", str(path)], check=False)
        if result.returncode != 0:
            fail("AAB JAR signature verification failed.")
        info("AAB signature verification: PASS")
    else:
        fail(f"Unknown Android artifact type: {kind}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_output(*args: str) -> str:
    result = run(["git", *args], check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def tool_version(command: list[str]) -> str:
    try:
        result = run(command, check=False)
        text = (result.stdout or result.stderr).strip().splitlines()
        return text[0] if text else "unavailable"
    except Exception:
        return "unavailable"


def generate_assets(dist: Path, artifacts: list[Path], environment: str, prerelease: bool) -> None:
    dist.mkdir(parents=True, exist_ok=True)
    meta = read_source_metadata()
    if os.getenv("VERSION_NAME"):
        meta["version"] = os.environ["VERSION_NAME"]
    if os.getenv("BUILD_NUMBER"):
        meta["build"] = int(os.environ["BUILD_NUMBER"])
    if os.getenv("RELEASE_NUMBER"):
        meta["release"] = os.environ["RELEASE_NUMBER"]

    existing = [p for p in artifacts if p.is_file()]
    if not existing:
        fail("No release artifacts were supplied for checksum/manifest generation.")

    hashes: dict[str, str] = {}
    for artifact in existing:
        hashes[artifact.name] = sha256(artifact)
        (dist / f"{artifact.name}.sha256.txt").write_text(f"{hashes[artifact.name]}  {artifact.name}\n", encoding="utf-8")

    sums = "".join(f"{hashes[name]}  {name}\n" for name in sorted(hashes))
    (dist / "SHA256SUMS.txt").write_text(sums, encoding="utf-8")

    manifest = {
        "application": "HomeVault",
        "packageId": PACKAGE_ID,
        "environment": environment,
        "versionName": meta["version"],
        "buildNumber": meta["build"],
        "releaseNumber": meta["release"],
        "gitSha": os.getenv("SOURCE_SHA") or os.getenv("GITHUB_SHA") or git_output("rev-parse", "HEAD"),
        "gitRef": os.getenv("SOURCE_REF") or os.getenv("GITHUB_REF_NAME") or git_output("branch", "--show-current"),
        "workflowRunId": os.getenv("GITHUB_RUN_ID", "local"),
        "buildTimestampUtc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "flutterVersion": os.getenv("FLUTTER_VERSION") or tool_version(["flutter", "--version"]),
        "dartVersion": tool_version(["dart", "--version"]),
        "javaVersion": tool_version(["java", "-version"]),
        "firebaseProjectId": os.getenv("HOMEVAULT_FIREBASE_PROJECT_ID") or os.getenv("PRODUCTION_FIREBASE_PROJECT_ID") or DEV_FIREBASE_PROJECT,
        "prerelease": prerelease,
        "artifacts": [{"name": p.name, "sha256": hashes[p.name], "bytes": p.stat().st_size} for p in existing],
    }
    manifest_path = dist / "release-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    json.loads(manifest_path.read_text(encoding="utf-8"))

    previous = git_output("tag", "--list", "homevault-*", "--sort=-creatordate").splitlines()
    previous_tag = previous[0].strip() if previous else ""
    range_arg = f"{previous_tag}..HEAD" if previous_tag else "HEAD"
    changes = git_output("log", range_arg, "--pretty=format:- %s (%h)", "--no-merges")
    if not changes:
        changes = "- No commit summary available."
    notes = [
        f"# HomeVault {meta['release']} — v{meta['version']}+{meta['build']}",
        "",
        f"- Environment: `{environment}`",
        f"- Source SHA: `{manifest['gitSha']}`",
        f"- Previous HomeVault tag: `{previous_tag or 'none'}`",
        "",
        "## Changes",
        changes,
        "",
        "## Artifacts",
    ]
    for p in existing:
        notes.append(f"- `{p.name}` — SHA-256 `{hashes[p.name]}`")
    notes += ["", "Integrity metadata is also available in `SHA256SUMS.txt` and `release-manifest.json`.", ""]
    (dist / "RELEASE_NOTES.md").write_text("\n".join(notes), encoding="utf-8")
    info("Release checksums, manifest, and notes: PASS")


def final_gate(dist: Path, require_aab: bool) -> None:
    required = [dist / "SHA256SUMS.txt", dist / "release-manifest.json", dist / "RELEASE_NOTES.md"]
    for path in required:
        if not path.is_file() or path.stat().st_size == 0:
            fail(f"Final release gate missing required file: {path.name}")
    manifest = json.loads((dist / "release-manifest.json").read_text(encoding="utf-8"))
    artifacts = manifest.get("artifacts", [])
    names = [str(item.get("name", "")) for item in artifacts]
    apks = [name for name in names if name.endswith(".apk")]
    aabs = [name for name in names if name.endswith(".aab")]
    if len(apks) != 1:
        fail("Final release gate requires exactly one APK in the release manifest.")
    if require_aab and len(aabs) != 1:
        fail("Stable manual release requires exactly one AAB in the release manifest.")
    sums = (dist / "SHA256SUMS.txt").read_text(encoding="utf-8")
    for item in artifacts:
        name = item["name"]
        path = dist / name
        if not path.is_file() or path.stat().st_size <= 0:
            fail(f"Final release gate artifact missing/empty: {name}")
        actual = sha256(path)
        if actual != item.get("sha256") or actual not in sums:
            fail(f"Final release gate checksum mismatch for {name}")
    info("FINAL RELEASE GATE: PASS")


def diagnostics(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    report = {
        "workflow": os.getenv("GITHUB_WORKFLOW", "local"),
        "job": os.getenv("GITHUB_JOB", "local"),
        "gitSha": os.getenv("GITHUB_SHA") or git_output("rev-parse", "HEAD"),
        "gitRef": os.getenv("GITHUB_REF", git_output("branch", "--show-current")),
        "flutter": tool_version(["flutter", "--version"]),
        "dart": tool_version(["dart", "--version"]),
        "java": tool_version(["java", "-version"]),
        "gradle": tool_version([str(ROOT / "android/gradlew"), "--version"]) if (ROOT / "android/gradlew").exists() else "unavailable",
        "pubspecLockTracked": run(["git", "ls-files", "--error-unmatch", "pubspec.lock"], check=False).returncode == 0,
    }
    (out_dir / "diagnostics.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    doctor = run(["flutter", "doctor", "-v"], check=False) if shutil.which("flutter") else None
    if doctor:
        (out_dir / "flutter-doctor.txt").write_text((doctor.stdout or "") + (doctor.stderr or ""), encoding="utf-8")
    info(f"Privacy-safe diagnostics written to {out_dir}")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("validate-ci")
    p.add_argument("--mode", choices=["development", "developer-release", "manual-release"], required=True)
    p.add_argument("--prerelease", choices=["true", "false"], default="true")

    sub.add_parser("validate-source")
    sub.add_parser("validate-lock")

    p = sub.add_parser("verify-artifact")
    p.add_argument("--path", required=True)
    p.add_argument("--kind", choices=["apk", "aab"], required=True)
    p.add_argument("--version")
    p.add_argument("--build")

    p = sub.add_parser("generate-assets")
    p.add_argument("--dist", default="dist")
    p.add_argument("--artifact", action="append", required=True)
    p.add_argument("--environment", choices=["development", "production"], required=True)
    p.add_argument("--prerelease", choices=["true", "false"], required=True)

    p = sub.add_parser("final-gate")
    p.add_argument("--dist", default="dist")
    p.add_argument("--require-aab", choices=["true", "false"], default="false")

    p = sub.add_parser("diagnostics")
    p.add_argument("--out", default="p15-diagnostics")

    args = parser.parse_args()
    os.chdir(ROOT)

    if args.command == "validate-ci":
        validate_ci(args.mode, args.prerelease == "true")
    elif args.command == "validate-source":
        validate_hygiene(); meta = read_source_metadata(); info(f"Source release metadata: PASS (v{meta['version']}+{meta['build']} {meta['release']})")
    elif args.command == "validate-lock":
        validate_lock()
    elif args.command == "verify-artifact":
        verify_artifact(Path(args.path), args.kind, args.version, args.build)
    elif args.command == "generate-assets":
        generate_assets(Path(args.dist), [Path(x) for x in args.artifact], args.environment, args.prerelease == "true")
    elif args.command == "final-gate":
        final_gate(Path(args.dist), args.require_aab == "true")
    elif args.command == "diagnostics":
        diagnostics(Path(args.out))


if __name__ == "__main__":
    main()
