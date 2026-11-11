# Actions Deploy Pipeline

## Problem statement

A small API passes its tests, but its delivery workflow has no test gate, uses a mutable image tag, and prepares a manifest that tries to pull an unpublished image. Exactly three fault groups. Repair the pipeline, not the application.

## Delivery contract

1. The `package` job must depend on successful `test`. Preserve default success-only scheduling; do not use `always()`, `continue-on-error`, or disable tests.
2. Both image archive and rendered manifest must use `delivery-api:<full commit SHA>` from `github.sha`. One `IMAGE_TAG` value controls both. Never hard-code a SHA or keep `latest`.
3. This is an **offline local deployment**: the image archive is loaded onto every cluster node before applying the rendered manifest. Set the template's pull policy to **Never**. No registry exists for this exercise. Preserve readiness and resources.

The workflow intentionally prepares a deployment artifact rather than reaching your laptop from a hosted runner. This follows the module's deployment-preparation option. No kind/cluster creation in Actions, registry credentials, paid service or secret required. Upstream `main` stays broken; all repairs go to your fork.

## Before timer

Fork and clone. Enable Actions in your public fork if GitHub displays an enable banner. Confirm standard free GitHub-hosted runners are available under your account/org policy; do not select a paid runner. Read [workstation prerequisites, ready checks and cleanup](SETUP.md), then run:

```bash
bash scripts/prepare-lab.sh
source .lab/env.sh
python3 -m unittest discover -s tests -v
kubectl -n "$NS" get pods
```

Setup creates an empty isolated cluster and namespace; it never applies the placeholder template. Tools and cluster preparation happen before timer. Artifact import later is a student-run ungraded transport step; no other person or cluster credentials in Actions are needed.

**Architecture boundary:** standard `ubuntu-latest` builds produce linux/amd64 images. Use an amd64 Docker engine/workstation (Linux, WSL2 or Intel macOS). Native Apple Silicon/arm64 is unsupported for this Q4 artifact: setup fails early rather than promising an image that cannot execute. Do not change workflow runners/build platform as an extra repair.

## Commands

```bash
python3 -m unittest discover -s tests -v
# edit .github/workflows/ci.yml and k8s/deployment.yaml
# commit + push to your fork, then Actions > Delivery pipeline > latest run
```

After final green run, download artifact `release-<full SHA>` from that run's Actions page. Unzip into `release/` at repository root; verify it contains `image.tar` and `deployment.yaml` directly, not another nested directory. Copy that run's full head SHA, not a later local commit. Keep artifact bytes unchanged.

```bash
source .lab/env.sh
# Replace the example value with final green run's full 40-character SHA:
RUN_SHA='replace-with-final-green-run-full-SHA'
bash scripts/load-release.sh release "$RUN_SHA"
# Helper checks archive tags and rendered image agree, then imports directly
# into every lab node's container runtime. It never edits or applies YAML.
kubectl -n delivery-ca apply -f release/deployment.yaml
kubectl -n delivery-ca rollout status deploy/delivery-api --timeout=90s
kubectl -n delivery-ca get pods
kubectl -n delivery-ca get deploy delivery-api -o jsonpath='{.spec.template.spec.containers[0].image}{" "}{.spec.template.spec.containers[0].imagePullPolicy}{"\n"}'
kubectl -n delivery-ca exec deploy/delivery-api -- python -c "import urllib.request as u;r=u.urlopen('http://localhost:5000/health');print('HTTP',r.status);print(r.read().decode())"
```

Template `k8s/deployment.yaml` contains a placeholder: apply **rendered artifact**, not template. Use only `delivery-ca` in this isolated cluster. Do not add cloud deployment, registry publication, or credentials. Edit only `.github/workflows/ci.yml` and `k8s/deployment.yaml`; preserve app, tests, Dockerfile and helper scripts. Commit/push repairs to your fork for genuine Actions evidence. Capture cause, fix, job order, full-SHA artifact/runtime consistency and verification in labelled screenshots; no separate notes file or PR required. Import after downloading final artifact is unavoidable, but is not an additional assessed repair. Pause timer for unrelated import/tool failures.
