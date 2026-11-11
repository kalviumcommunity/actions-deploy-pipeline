#!/usr/bin/env bash
# Imports, but never edits or applies, the final GitHub Actions release.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARTIFACT=$(cd "${1:?Usage: bash scripts/load-release.sh <unpacked-artifact-directory> <full-run-SHA>}" && pwd)
SHA="${2:?full 40-character run SHA required}"
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected full lowercase 40-character run SHA.' >&2; exit 1; }
for tool in docker kubectl python3; do command -v "$tool" >/dev/null; done
[ -f "$ROOT/.lab/prepared" ] || { echo 'Run prepare-lab.sh before timer.' >&2; exit 1; }
# Reject mismatched artifact/image/manifest. Never substitute or retag anything.
python3 - "$ARTIFACT" "$SHA" <<'PY'
import json, pathlib, re, sys, tarfile
root, sha = pathlib.Path(sys.argv[1]), sys.argv[2]
expected = 'delivery-api:' + sha
with tarfile.open(root/'image.tar') as archive:
    member = archive.getmember('manifest.json')
    if member.size > 1024*1024: raise SystemExit('Invalid archive manifest size')
    manifests = json.load(archive.extractfile(member))
    tags = [tag for item in manifests for tag in item.get('RepoTags', [])]
    if tags != [expected]: raise SystemExit(f'Archive tags {tags} do not match {expected}')
text = (root/'deployment.yaml').read_text()
images = re.findall(r'^\s*image:\s*[\'"]?([^\s\'"#]+)', text, re.M)
if images != [expected]: raise SystemExit(f'Rendered manifest images {images} do not match {expected}')
print('Artifact matches:', expected)
PY
[ "$(docker info --format '{{.Architecture}}')" = x86_64 ] || [ "$(docker info --format '{{.Architecture}}')" = amd64 ] || { echo 'Use amd64 Docker engine for hosted-runner artifacts.' >&2; exit 1; }
CLUSTER=cloud-m4-q4
KIND="$ROOT/.lab/bin/kind"
NODES=$("$KIND" get nodes --name "$CLUSTER")
[ -n "$NODES" ] || { echo 'Lab cluster missing.' >&2; exit 1; }
# Direct archive import into each eligible node; docker load alone is insufficient.
for node in $NODES; do
  docker exec --privileged -i "$node" ctr --namespace=k8s.io images import --platform linux/amd64 --digests - < "$ARTIFACT/image.tar"
  docker exec "$node" ctr --namespace=k8s.io images list | grep -F "delivery-api:$SHA"
done
echo 'Image loaded on every lab node. No manifests applied or modified.'
echo "Next: kubectl -n delivery-ca apply -f \"$ARTIFACT/deployment.yaml\""
