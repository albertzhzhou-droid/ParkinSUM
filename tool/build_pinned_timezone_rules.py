"""Rebuild a fixed IANA candidate; only exact reviewed bytes may replace the asset."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tarfile
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--archive', required=True)
parser.add_argument('--zic', default='/usr/sbin/zic')
parser.add_argument('--write-reviewed-asset', action='store_true')
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parent.parent
plan = json.loads((root / 'test/fixtures/timezone_research/frozen_plan_before_compilation.json').read_text())
manifest = json.loads((root / 'assets/timezone/iana_2026e_manifest.json').read_text())
archive = pathlib.Path(args.archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != plan['archive_sha256']:
    raise ValueError('Official fixed archive identity mismatch; no candidate produced.')
output = root / 'build/timezone_rules_compiler'
output.mkdir(parents=True, exist_ok=True)
candidate = output / 'reviewed_candidate.tzf'
with tempfile.TemporaryDirectory(prefix='parkinsum-tz-') as temporary:
    temporary = pathlib.Path(temporary)
    sources = []
    with tarfile.open(archive) as source:
        for name, expected in plan['selected_source_members'].items():
            data = source.extractfile(name).read()
            if hashlib.sha256(data).hexdigest() != expected['sha256']:
                raise ValueError('Fixed selected source member identity mismatch.')
            target = temporary / name
            target.write_bytes(data)
            if name not in ['LICENSE', 'version']:
                sources.append(str(target))
    zones = temporary / 'zoneinfo'
    zones.mkdir()
    subprocess.run([args.zic, '-b', 'fat', '-r', '@-2208988800/@4102444800', '-d', str(zones), *sources], check=True, timeout=120)
    subprocess.run(['dart', 'run', 'tool/encode_pinned_timezone_rules.dart', str(zones), str(candidate)], cwd=root, check=True, timeout=600)
digest = hashlib.sha256(candidate.read_bytes()).hexdigest()
if digest != manifest['asset_sha256']:
    raise ValueError('Rebuilt candidate differs from reviewed artifact; retained in ignored output for review, existing asset preserved.')
if args.write_reviewed_asset:
    candidate.replace(root / manifest['asset_path'])
print(json.dumps({'pass': True, 'asset_sha256': digest, 'reviewed_asset_written': args.write_reviewed_asset, 'boundary': 'Fixed source/codec byte reproduction only; not new release, all-zone validation or legal/clinical qualification.'}))
