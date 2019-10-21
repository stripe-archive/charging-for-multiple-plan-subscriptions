#!/usr/bin/env bash
########
# bootstrap.sh
#
# This script cleanups up the Stripe-side entities created to run the sample in this repo.
#
# Usage: ./cleanup.sh
# Requirements: curl, jq, a Stripe account, and a well formed .env file (see ./README.md)
########


REPO_ROOT=$(cd $(dirname $0)/.. && pwd)
DOTENV_FILE="${REPO_ROOT}/.env"
. "${REPO_ROOT}/scripts/utilities.sh"


if [ ! -f "${DOTENV_FILE}" ]; then
  echo ".env file not found at ${DOTENV_FILE}. Please follow the instructions in ${REPO_ROOT}/README.md to create one."
  exit 1
fi

. "${DOTENV_FILE}"

### Ensure .env file contains credentials.
if [ -z "${STRIPE_SECRET_KEY}" ]; then
  echo ".env file exists, but does not set the STRIPE_SECRET_KEY property."
  exit 1
fi

### ensure curl and jq are installed
if ! command -v curl > /dev/null ; then
  echo "curl is required."
  exit 1
fi

if ! command -v jq > /dev/null ; then
  echo "jq is required."
  exit 1
fi

### Helper Functions
function get_plan_id() {
  local PLAN_NAME=$1
  echo "stripe-example-${PLAN_NAME}"
}

function get_pricing_plan() {
  local NAME=$1
  PLAN_ID="$(get_plan_id "${NAME}")"
  PLAN_RESOURCE="https://api.stripe.com/v1/plans/${PLAN_ID}"
  stripe_curl "${PLAN_RESOURCE}"
}

function delete_pricing_plan() {
  local NAME=$1
  PLAN_ID="$(get_plan_id "${NAME}")"
  PLAN_RESOURCE="https://api.stripe.com/v1/plans/${PLAN_ID}"
  # delete plan
  stripe_curl -X DELETE "${PLAN_RESOURCE}"
}

function delete_product() {
  local PRODUCT_ID=$1
  stripe_curl -X DELETE https://api.stripe.com/v1/products/${PRODUCT_ID}
}

function delete_coupon() {
  local PRODUCT_NAME=$1
  local PERCENT_OFF=$2
  local COUPON_ID="${PRODUCT_NAME}_${PERCENT_OFF}OFF"
  stripe_curl -X DELETE "https://api.stripe.com/v1/coupons/${COUPON_ID}"
}

# Example specific code:
# ANIMALS comes from the .env file

# delete pricing plan (and corresponding service product) for each animal
IFS=',' read -r -a ANIMAL_LIST <<< "${ANIMALS}"
debug ANIMAL_LIST
for animal in "${ANIMAL_LIST[@]}"; do
  # get pricing plan for each animal to get associated product
  RESULT=$(get_pricing_plan "${animal}")
  ERROR=$(echo "${RESULT}" | jq -e .error)
  error_check_status=$?
  if [ $error_check_status -gt 0 ]; then
    # grab product id from plan
    PRODUCT_ID=$(echo "${RESULT}" | jq --raw-output .product)
    # delete pricing plan for each animal
    RESULT=$(delete_pricing_plan "${animal}")
    describe_api_result "${RESULT}" "delete plan for ${animal}"
    # delete product
    RESULT=$(delete_product ${PRODUCT_ID})
    describe_api_result "${RESULT}" "delete product for ${animal}"
  else
    warn "Plan for ${animal} does not exist, skipping."
  fi
done

# delete coupon
RESULT=$(delete_coupon "STRIPE_SAMPLE_MULTI_PLAN_DISCOUNT" 20)
describe_api_result "${RESULT}" "delete sample coupon"



