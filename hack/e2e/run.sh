#!/bin/bash

# Copyright 2019 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

function test_run_id() {
    echo "$(date '+%Y%m%d%H%M%S')"
}

test_run_id="$(test_run_id)"
repo_root="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/../.." &> /dev/null && pwd )"
output="${repo_root}/_output"
test_output_root="${output}/test"
test_run="${test_output_root}/${test_run_id}"

# Configurable
#KUBECONFIG="${KUBECONFIG:-}"
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-}"

KUBERNETES_VERSION="${KUBERNETES_VERSION:-v1.23.2}"
GINKGO_VERSION="v1.14.0"
CLUSTER_NAME="test-cluster-${test_run_id}.k8s.local"
KOPS_STATE_STORE="${KOPS_STATE_STORE:-}"
REGION="${AWS_REGION:-us-west-2}"
ZONES="${AWS_AVAILABILITY_ZONES:-us-west-2a,us-west-2b,us-west-2c}"

# Test args
GINKGO_FOCUS=${GINKGO_FOCUS:-"\[cloud-provider-aws-e2e\]"}
GINKGO_SKIP=${GINKGO_SKIP:-"\[Disruptive\]"}
GINKGO_NODES=${GINKGO_NODES:-4}

if [[ -z "${KOPS_STATE_STORE}" ]]; then
    echo "KOPS_STATE_STORE must be set"
    exit 1
fi

if [[ ! -f "${repo_root}/e2e.test" ]]; then
    echo "Missing e2e.test binary"
    exit 1
fi

echo "Starting test run ---"
echo " + Region:             ${REGION} (${ZONES})"
echo " + Cluster name:       ${CLUSTER_NAME}"
echo " + Kubernetes version: ${KUBERNETES_VERSION}"
echo " + Focus:              ${GINKGO_FOCUS}"
echo " + Skip:               ${GINKGO_SKIP}"
echo " + Kops state store:   ${KOPS_STATE_STORE}"
echo " + SSH key path:       ${SSH_PUBLIC_KEY_PATH}"
echo " + Test run ID:        ${test_run_id}"
echo " + Kubetest run dir:   ${test_run}"

mkdir -p "${test_run}"

export KOPS_STATE_STORE
export ARTIFACTS="${test_output_root}"
export KUBETEST2_RUN_DIR="${test_output_root}"

echo "Installing e2e.test to ${test_run}"
cp "${repo_root}/e2e.test" "${test_run}"

echo "Installing ginkgo to ${test_run}"
GINKGO_BIN=${test_run}/ginkgo
if [[ ! -f ${GINKGO_BIN} ]]; then
  GOBIN=${test_run} go install "github.com/onsi/ginkgo/ginkgo@${GINKGO_VERSION}"
fi

kubetest2 kops \
  -v 2 \
  --up \
  --run-id=${test_run_id} \
  --cloud-provider=aws \
  --cluster-name=${CLUSTER_NAME} \
  --create-args="--zones=${ZONES} --node-size=m5.large --master-size=m5.large" \
  --admin-access="0.0.0.0/0" \
  --kubernetes-version=${KUBERNETES_VERSION} \
  --ssh-public-key="${SSH_PUBLIC_KEY_PATH}" \
  --kops-version-marker=https://storage.googleapis.com/kops-ci/bin/latest-ci-updown-green.txt \
  --test=kops \
  -- \
  --use-built-binaries=true \
  --focus-regex="${GINKGO_FOCUS}" \
  --parallel 25

