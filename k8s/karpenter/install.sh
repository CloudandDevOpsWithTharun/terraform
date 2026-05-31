#!/bin/bash
set -euo pipefail

CLUSTER_NAME="prime360novac-1"
REGION="ap-southeast-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
KARPENTER_VERSION="1.8.1"
KARPENTER_NAMESPACE="karpenter"
KARPENTER_ROLE_NAME="${CLUSTER_NAME}-karpenter-controller"
INTERRUPTION_QUEUE="${CLUSTER_NAME}-karpenter-interruption"
NODE_ROLE_NAME="${CLUSTER_NAME}-node-role"

echo "════════════════════════════════════════════"
echo " Karpenter Production Install"
echo " Cluster : $CLUSTER_NAME"
echo " Region  : $REGION"
echo " Account : $ACCOUNT_ID"
echo "════════════════════════════════════════════"

# ──────────────────────────────────────────────
# STEP 1 — Tag cluster SG for Karpenter discovery
# Your private subnets already have karpenter.sh/discovery tag
# Only the SG needs tagging — it's the default cluster SG
# ──────────────────────────────────────────────
echo ""
echo "▶ Step 1/6 — Tagging cluster security group..."

CLUSTER_SG=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
  --output text)

aws ec2 create-tags \
  --resources "$CLUSTER_SG" \
  --tags "Key=karpenter.sh/discovery,Value=$CLUSTER_NAME" \
  --region "$REGION"

echo "  Tagged SG: $CLUSTER_SG"

# ──────────────────────────────────────────────
# STEP 2 — SQS queue for interruption handling
# ──────────────────────────────────────────────
echo ""
echo "▶ Step 2/6 — Creating SQS interruption queue..."

QUEUE_URL=$(aws sqs create-queue \
  --queue-name "$INTERRUPTION_QUEUE" \
  --attributes '{
    "MessageRetentionPeriod": "300",
    "SqsManagedSseEnabled": "true"
  }' \
  --region "$REGION" \
  --query QueueUrl \
  --output text 2>/dev/null || \
  aws sqs get-queue-url \
    --queue-name "$INTERRUPTION_QUEUE" \
    --region "$REGION" \
    --query QueueUrl \
    --output text)

QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names QueueArn \
  --region "$REGION" \
  --query "Attributes.QueueArn" \
  --output text)

echo "  Queue ARN: $QUEUE_ARN"

aws sqs set-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --region "$REGION" \
  --attributes "{
    \"Policy\": \"{\\\"Version\\\":\\\"2012-10-17\\\",\\\"Statement\\\":[{\\\"Effect\\\":\\\"Allow\\\",\\\"Principal\\\":{\\\"Service\\\":[\\\"events.amazonaws.com\\\",\\\"sqs.amazonaws.com\\\"]},\\\"Action\\\":\\\"sqs:SendMessage\\\",\\\"Resource\\\":\\\"$QUEUE_ARN\\\"}]}\"
  }"

# ──────────────────────────────────────────────
# STEP 3 — EventBridge rules → SQS
# ──────────────────────────────────────────────
echo ""
echo "▶ Step 3/6 — Creating EventBridge rules..."

declare -A RULES
RULES["${CLUSTER_NAME}-spot-interruption"]='{"source":["aws.ec2"],"detail-type":["EC2 Spot Instance Interruption Warning"]}'
RULES["${CLUSTER_NAME}-rebalance"]='{"source":["aws.ec2"],"detail-type":["EC2 Instance Rebalance Recommendation"]}'
RULES["${CLUSTER_NAME}-state-change"]='{"source":["aws.ec2"],"detail-type":["EC2 Instance State-change Notification"]}'
RULES["${CLUSTER_NAME}-scheduled-change"]='{"source":["aws.health"],"detail-type":["AWS Health Event"]}'

for RULE_NAME in "${!RULES[@]}"; do
  aws events put-rule \
    --name "$RULE_NAME" \
    --event-pattern "${RULES[$RULE_NAME]}" \
    --state ENABLED \
    --region "$REGION" \
    --query RuleArn \
    --output text > /dev/null

  aws events put-targets \
    --rule "$RULE_NAME" \
    --targets "Id=1,Arn=$QUEUE_ARN" \
    --region "$REGION" > /dev/null

  echo "  Rule: $RULE_NAME"
done

# ──────────────────────────────────────────────
# STEP 4 — IAM role for Karpenter controller
# Pod Identity principal — no OIDC
# ──────────────────────────────────────────────
echo ""
echo "▶ Step 4/6 — Creating Karpenter IAM role..."

TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "pods.eks.amazonaws.com" },
    "Action": ["sts:AssumeRole", "sts:TagSession"]
  }]
}
EOF
)

aws iam create-role \
  --role-name "$KARPENTER_ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" 2>/dev/null \
  || echo "  Role already exists, continuing..."

CONTROLLER_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2NodeManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:CreateLaunchTemplate",
        "ec2:CreateFleet",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeInstanceTypeOfferings",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeSpotPriceHistory",
        "ec2:DescribeImages",
        "ec2:DescribeVpcs",
        "ec2:DeleteLaunchTemplate",
        "ec2:TerminateInstances",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassNodeRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/${NODE_ROLE_NAME}"
    },
    {
      "Sid": "IAMInstanceProfile",
      "Effect": "Allow",
      "Action": [
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:TagInstanceProfile"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SQSInterruption",
      "Effect": "Allow",
      "Action": [
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage"
      ],
      "Resource": "${QUEUE_ARN}"
    },
    {
      "Sid": "EKSClusterAccess",
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster"],
      "Resource": "arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}"
    },
    {
      "Sid": "SSMAMILookup",
      "Effect": "Allow",
      "Action": ["ssm:GetParameter"],
      "Resource": "arn:aws:ssm:${REGION}::parameter/aws/service/*"
    },
    {
      "Sid": "PricingLookup",
      "Effect": "Allow",
      "Action": ["pricing:GetProducts"],
      "Resource": "*"
    }

  ]
}
EOF
)

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${CLUSTER_NAME}-karpenter-policy"

aws iam create-policy \
  --policy-name "${CLUSTER_NAME}-karpenter-policy" \
  --policy-document "$CONTROLLER_POLICY" 2>/dev/null || \
aws iam create-policy-version \
  --policy-arn "$POLICY_ARN" \
  --policy-document "$CONTROLLER_POLICY" \
  --set-as-default > /dev/null

aws iam attach-role-policy \
  --role-name "$KARPENTER_ROLE_NAME" \
  --policy-arn "$POLICY_ARN" 2>/dev/null || true

echo "  IAM role ready: $KARPENTER_ROLE_NAME"

# ──────────────────────────────────────────────
# STEP 5 — Pod Identity association
# ──────────────────────────────────────────────
echo ""
echo "▶ Step 5/6 — Creating Pod Identity association..."

KARPENTER_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${KARPENTER_ROLE_NAME}"

aws eks create-pod-identity-association \
  --cluster-name "$CLUSTER_NAME" \
  --namespace "$KARPENTER_NAMESPACE" \
  --service-account "karpenter" \
  --role-arn "$KARPENTER_ROLE_ARN" \
  --region "$REGION" 2>/dev/null \
  || echo "  Association already exists, skipping..."

# ──────────────────────────────────────────────
# STEP 6 — Helm install + apply manifests
# ──────────────────────────────────────────────
echo ""
echo "▶ Step 6/6 — Installing Karpenter via Helm..."

kubectl create namespace karpenter \
  --dry-run=client -o yaml | kubectl apply -f -

CLUSTER_ENDPOINT=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query "cluster.endpoint" \
  --output text)

helm upgrade --install karpenter \
  oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace "${KARPENTER_NAMESPACE}" \
  --create-namespace \
  --values values.yaml \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.clusterEndpoint=${CLUSTER_ENDPOINT}" \
  --set "settings.interruptionQueue=${INTERRUPTION_QUEUE}" \
  --wait \
  --timeout 10m
echo "▶ Applying NodePool and EC2NodeClass..."

export CLUSTER_NAME NODE_ROLE_NAME
envsubst < ec2nodeclass.yaml | kubectl apply -f -
kubectl apply -f nodepool.yaml

echo ""
echo "════════════════════════════════════════════"
kubectl rollout status deployment/karpenter -n "$KARPENTER_NAMESPACE"
kubectl get nodepools
kubectl get ec2nodeclasses
echo ""
echo "✅ Karpenter installed successfully"
echo "Monitor: kubectl logs -n $KARPENTER_NAMESPACE -l app.kubernetes.io/name=karpenter -f"