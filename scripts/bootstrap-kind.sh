#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-realtime-dev}"

kind create cluster --name "${CLUSTER_NAME}" --wait 120s
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "kind cluster '${CLUSTER_NAME}' is ready"
echo "Wait for Argo CD pods to become Ready, then apply manifests from ./argocd"
