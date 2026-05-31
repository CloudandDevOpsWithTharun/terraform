#!/bin/bash
set -euo pipefail

CLUSTER_NAME="prime360novac-1"     # your cluster name from the screenshot
REGION="ap-southeast-1"
NAMESPACE="kube-system"
CILIUM_VERSION="1.15.6"            # latest stable as of now — check before applying

echo "──────────────────────────────────────────"
echo " Fetching EKS API Server endpoint..."
echo "──────────────────────────────────────────"

API_SERVER=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query "cluster.endpoint" \
  --output text | sed 's|https://||')

echo "API Server: $API_SERVER"

──────────────────────────────────────────"

# kube-proxy addon removed from Terraform — but daemonset may still exist
# safe to delete since Cilium takes over

echo "──────────────────────────────────────────"
echo " Adding Cilium Helm repo..."
echo "──────────────────────────────────────────"

helm repo add cilium https://helm.cilium.io/
helm repo update

echo "──────────────────────────────────────────"
echo " Installing Cilium..."
echo "──────────────────────────────────────────"

helm upgrade --install cilium cilium/cilium \
  --version "$CILIUM_VERSION" \
  --namespace "$NAMESPACE" \
  --values values.yaml \
  --set k8sServiceHost="$API_SERVER" \
  --set k8sServicePort="443" \
  --wait \
  --timeout 5m

echo "──────────────────────────────────────────"
echo " Verifying Cilium status..."
echo "──────────────────────────────────────────"

kubectl rollout status daemonset/cilium -n kube-system
kubectl rollout status deployment/cilium-operator -n kube-system
kubectl rollout status deployment/hubble-relay -n kube-system
kubectl rollout status deployment/hubble-ui -n kube-system

echo ""
echo "✅ Cilium installed successfully"
echo ""
kubectl delete daemonset kube-proxy -n kube-system --ignore-not-found
echo "──────────────────────────────────────────"
echo " Removing kube-proxy daemonset..."
echo " (Cilium will replace it)"
echo "
echo "Access Hubble UI:"
echo "  kubectl port-forward svc/hubble-ui -n kube-system 12000:80"
echo "  then open http://localhost:12000"