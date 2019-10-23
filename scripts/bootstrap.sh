#!/usr/bin/env bash
########
# bootstrap.sh
#
# This script sets up the necessary Stripe-side entities to run the sample in this repo.
#
# Usage: ./bootstrap.sh
# Requirements: curl, jq, a Stripe account, and a well formed .env file (see ./README.md)
########

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
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

### Helper Functions
function create_pricing_plan() {
  local NAME=$1
  local PRICE=$2
  stripe_curl https://api.stripe.com/v1/plans \
    -d "product[name]=stripe-example-${NAME}" \
    -d interval=month \
    -d amount="${PRICE}" \
    -d currency=usd \
    -d id="stripe-example-${NAME}"
}

function create_coupon() {
  local PRODUCT_NAME=$1
  local PERCENT_OFF=$2
  stripe_curl https://api.stripe.com/v1/coupons \
    -d percent_off="${PERCENT_OFF}" \
    -d id="${PRODUCT_NAME}_${PERCENT_OFF}OFF" \
    -d duration=forever
  return $?
}

# Example specific code:
# ANIMALS and PRICES are located in the .env file
IFS=',' read -r -a ANIMAL_LIST <<< "${ANIMALS}"
IFS=',' read -r -a PRICE_LIST <<< "${PRICES}"
unset IFS

# create a pricing plan (and a corresponding service product) for each animal
for (( idx=0; idx < ${#ANIMAL_LIST[@]}; idx++ )); do
  animal=${ANIMAL_LIST[$idx]}
  price=${PRICE_LIST[$idx]}
  # create a pricing plan for each animal
  RESULT=$(create_pricing_plan "${animal}" "${price}")
  describe_api_result "${RESULT}" "create plan for ${animal}"
done

# create a coupon
RESULT=$(create_coupon "STRIPE_SAMPLE_MULTI_PLAN_DISCOUNT" 20)
describe_api_result "${RESULT}" "Create coupon for bulk discount"


