"""Build and verify the reproducible addon archive using Python's standard library."""

from hashlib import sha256
from io import BytesIO
from pathlib import Path, PurePosixPath
import re
import struct
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
ADDON_NAME = "WowfPartyFrames"
ADDON = ROOT / ADDON_NAME
TOC_NAME = ADDON_NAME + ".toc"
FIXED_TIME = (1980, 1, 1, 0, 0, 0)


def toc_files(text):
    files = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name = line.replace("\\", "/")
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or ":" in name or path.suffix.lower() != ".lua":
            raise ValueError(f"Unexpected TOC entry: {line!r}")
        if name in files:
            raise ValueError(f"Duplicate TOC entry: {name}")
        files.append(name)
    if not files:
        raise ValueError("TOC has no addon files")
    return files


def build():
    toc_bytes = (ADDON / TOC_NAME).read_bytes()
    toc_text = toc_bytes.decode("utf-8-sig")
    version_match = re.search(r"^## Version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$", toc_text, re.MULTILINE)
    if not version_match:
        raise ValueError("TOC must declare a numeric major.minor.patch version")
    listed = toc_files(toc_text)
    payload = {TOC_NAME: toc_bytes}
    for name in listed:
        source = ADDON.joinpath(*PurePosixPath(name).parts).resolve()
        if not source.is_relative_to(ADDON.resolve()) or not source.is_file():
            raise ValueError(f"TOC file missing or outside addon folder: {name}")
        payload[name] = source.read_bytes()
    # Original radial art is an explicit manifest; no work files or unrelated
    # screenshots enter the addon archive. These names match CleanseGeometry.
    assets = {
        f"Media/cleanse-{style}-{count}-{index}-{layer}.tga"
        for style in ("buttons", "quadrants")
        for count in (2, 3, 4)
        for index in range(1, count + 1)
        for layer in ("fill", "rim", "glow")
    }
    actual_assets = {p.relative_to(ADDON).as_posix() for p in (ADDON / "Media").glob("*.tga")}
    if actual_assets != assets:
        raise ValueError("Radial artwork does not match its package manifest")
    for name in sorted(assets):
        source = ADDON.joinpath(*PurePosixPath(name).parts).resolve()
        if not source.is_relative_to(ADDON.resolve()):
            raise ValueError(f"Asset outside addon folder: {name}")
        data = source.read_bytes()
        if len(data) != 18 + 256 * 256 * 4 or data[2] != 2 or data[16] != 32 \
                or struct.unpack_from("<HH", data, 12) != (256, 256):
            raise ValueError(f"Unexpected TGA dimensions/encoding: {name}")
        payload[name] = data
    # Only source, original artwork, and user documentation ship.
    payload["README.md"] = (ROOT / "README.md").read_text(encoding="utf-8-sig").replace(
        "(tests/IN_GAME_CHECKLIST.md)", "(CHECKLIST.md)"
    ).encode("utf-8")
    payload["CHECKLIST.md"] = (ROOT / "tests" / "IN_GAME_CHECKLIST.md").read_bytes()

    buffer = BytesIO()
    with ZipFile(buffer, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for name in sorted(payload):
            entry = ZipInfo(f"{ADDON_NAME}/{name}", date_time=FIXED_TIME)
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            entry.compress_type = ZIP_DEFLATED
            archive.writestr(entry, payload[name], compress_type=ZIP_DEFLATED, compresslevel=9)

    contents = buffer.getvalue()
    with ZipFile(BytesIO(contents)) as archive:
        expected = {f"{ADDON_NAME}/{name}" for name in payload}
        if set(archive.namelist()) != expected or len(archive.namelist()) != len(expected):
            raise ValueError("Archive contents do not match the explicit package manifest")
        bad_file = archive.testzip()
        if bad_file:
            raise ValueError(f"Archive CRC verification failed: {bad_file}")
        archived_toc = archive.read(f"{ADDON_NAME}/{TOC_NAME}").decode("utf-8-sig")
        for name in toc_files(archived_toc):
            if archive.read(f"{ADDON_NAME}/{name}") != payload[name]:
                raise ValueError(f"Packaged TOC source mismatch: {name}")
        for name, data in payload.items():
            if archive.read(f"{ADDON_NAME}/{name}") != data:
                raise ValueError(f"Packaged file mismatch: {name}")

    destination = ROOT / "dist" / f"{ADDON_NAME}-{version_match.group(1)}.zip"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(contents)
    digest = sha256(contents).hexdigest()
    destination.with_suffix(".zip.sha256").write_text(
        f"{digest}  {destination.name}\n", encoding="ascii", newline="\n"
    )
    print(f"Verified {len(payload)} files: {destination.relative_to(ROOT)}")
    print(f"SHA256: {digest}")


if __name__ == "__main__":
    build()
