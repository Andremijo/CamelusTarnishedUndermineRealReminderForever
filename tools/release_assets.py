"""Build and check the files a GitHub Release needs so WoWUp can install the addon.

    python3 tools/release_assets.py            # writes dist/ and prints the asset names

WoWUp's "Install from URL" (GitHub provider) picks a release asset for a
WoW: Forever install in one of two ways, and this script satisfies both:
  1. release.json (BigWigs packager format) listing the zip under the
     "forever" flavor, with "nolib": false and the exact asset filename;
  2. otherwise, a zip whose filename ends in "-forever.zip".
It also needs a .zip asset (application/zip), a published non-draft release,
and the addon folder at the root of the zip with a .toc named like the folder.

Outputs in dist/:
  <ASSET_BASE>-v<version>-forever.zip   the addon zip (same bytes as releases/)
  release.json                          WoWUp / BigWigs metadata
  asset_label.txt                       display label for the zip on GitHub
"""
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = "TarnishedRealReminder"
TOC = os.path.join(ROOT, ADDON, ADDON + ".toc")
DISPLAY_NAME = "Camelus' Tarnished Undermine Real Reminder"
# GitHub rewrites spaces and quotes in uploaded file names, and WoWUp matches on
# the exact name, so the asset itself gets a plain name; the label keeps the
# display name.
ASSET_BASE = "Camelus-Tarnished-Undermine-Real-Reminder"
WOWUP_FOREVER_RE = re.compile(r"[-_](forever|camelot)\.zip$", re.I)  # WoWUp isForever()


def fail(msg):
    print("error: " + msg, file=sys.stderr)
    sys.exit(1)


def toc_field(name):
    with open(TOC, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^## %s:\s*(.+?)\s*$" % re.escape(name), line)
            if m:
                return m.group(1)
    return None


def check_zip(path, interface):
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
    roots = {n.split("/")[0] for n in names}
    if roots != {ADDON}:
        fail(f"zip must hold exactly one folder '{ADDON}' at its root, found {sorted(roots)}")
    toc_in_zip = f"{ADDON}/{ADDON}.toc"
    if toc_in_zip not in names:
        fail(f"zip is missing {toc_in_zip}")
    with zipfile.ZipFile(path) as z:
        toc_text = z.read(toc_in_zip).decode("utf-8")
        listed = [l.strip() for l in toc_text.splitlines() if l.strip().endswith(".lua") and not l.startswith("#")]
        for lua in listed:
            if f"{ADDON}/{lua}" not in names:
                fail(f"zip is missing {lua}, which the .toc loads")
    m = re.search(r"^## Interface:\s*(.+)$", toc_text, re.M)
    if not m or str(interface) not in [s.strip() for s in m.group(1).split(",")]:
        fail("zipped .toc has a different ## Interface than the source .toc")


def main():
    version = toc_field("Version")
    interface_line = toc_field("Interface")
    if not version or not re.fullmatch(r"\d+\.\d+\.\d+", version):
        fail(f"bad ## Version in the .toc: {version!r}")
    if not interface_line:
        fail("no ## Interface in the .toc")
    interface = int(interface_line.split(",")[0].strip())
    # WoWUp reads 1.60+ (interface 16000+) as Forever.
    if not (16000 <= interface < 20000):
        fail(f"## Interface {interface} is not a WoW: Forever interface (16xxx)")

    src = os.path.join(ROOT, "releases", f"{DISPLAY_NAME} v{version}.zip")
    if not os.path.isfile(src):
        subprocess.run([os.path.join(ROOT, "tools", "build_zip.sh")], check=True)
    check_zip(src, interface)

    dist = os.path.join(ROOT, "dist")
    shutil.rmtree(dist, ignore_errors=True)
    os.makedirs(dist)
    asset = f"{ASSET_BASE}-v{version}-forever.zip"
    if not WOWUP_FOREVER_RE.search(asset):
        fail(f"{asset} would not be recognised by WoWUp as a Forever zip")
    shutil.copyfile(src, os.path.join(dist, asset))

    meta = {
        "releases": [
            {
                "name": DISPLAY_NAME,
                "version": f"v{version}",
                "filename": asset,
                "nolib": False,
                "metadata": [{"flavor": "forever", "interface": interface}],
            }
        ]
    }
    with open(os.path.join(dist, "release.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    with open(os.path.join(dist, "asset_label.txt"), "w", encoding="utf-8") as f:
        f.write(f"{DISPLAY_NAME} v{version}")

    print(asset)


if __name__ == "__main__":
    main()
