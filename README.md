# Actions Deploy Pipeline

A small API passes its tests, but its delivery workflow has no test gate, uses a mutable image tag, and prepares a manifest that tries to pull an unpublished image. Exactly three fault groups. Repair the pipeline, not the application.

## Delivery contract

1. The `package` job must depend on successful `test`. Preserve default success-only scheduling; do not use `always()`, `continue-on-error`, or disable tests.
2. Both image archive and rendered manifest must use `delivery-api:<full commit SHA>` from `github.sha`. One `IMAGE_TAG` value controls both. Never hard-code a SHA or keep `latest`.
3. This is an **offline local deployment**: the image archive is loaded onto every cluster node before applying the rendered manifest. Set the template's pull policy to **Never**. No registry exists for this exercise. Preserve readiness and resources.

The workflow intentionally prepares a deployment artifact rather than reaching your laptop from a hosted runner. This follows the module's deployment-preparation option. No kind/cluster creation in Actions, registry credentials, paid service or secret required. Upstream `main` stays broken; all repairs go to your fork.

## Before timer

Fork and clone. Enable Actions in your fork if GitHub displays an enable banner. Use a public fork with free standard GitHub-hosted runners (subject to account/org policy); instructor confirms workflow access. Instructor provides a free local Kubernetes cluster and kubectl, Docker, Python 3 and editor. Installation and image loading are not assessed.

## Commands

```bash
python3 -m unittest discover -s tests -v
# edit .github/workflows/ci.yml and k8s/deployment.yaml
# commit + push to your fork, then Actions > Delivery pipeline > latest run
```

After green run, download artifact `release-<full SHA>` from that run and unzip it. It contains `image.tar` and `deployment.yaml`. Verify both use the run's full SHA, then give archive to instructor to load into cluster nodes:

```bash
docker load -i image.tar
# kind: kind load docker-image delivery-api:<full-SHA> --name <cluster>
# minikube: minikube image load delivery-api:<full-SHA>
# Docker Desktop: instructor ensures image is in Kubernetes node runtime too.
kubectl create namespace delivery-ca
kubectl -n delivery-ca apply -f deployment.yaml
kubectl -n delivery-ca rollout status deploy/delivery-api --timeout=90s
kubectl -n delivery-ca get pods
kubectl -n delivery-ca exec deploy/delivery-api -- python -c "import urllib.request as u;r=u.urlopen('http://localhost:5000/health');print('HTTP',r.status);print(r.read().decode())"
```

Template `k8s/deployment.yaml` contains a placeholder: apply **rendered artifact**, not template. Use only assigned namespace. Do not add cloud deployment, registry publication, or credentials. Edit only workflow, manifest template, and your `repair-notes.md`. Record cause, fix and verification for all tasks; commit them to fork. No PR required.
