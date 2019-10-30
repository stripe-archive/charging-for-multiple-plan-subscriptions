#!/usr/bin/env bash
########
# integ.sh
#
# This script sets up the necessary Stripe-side entities to run the sample in this repo.
#
# Usage: ./bootstrap.sh [/path/to/server]
#
# Run integration tests against all servers. If /path/to/server is specified, script will try to run only the server at that path.
#
# Requirements: curl, jq, a Stripe account, and a well formed .env file (see ./README.md)
########


REPO_ROOT=$(cd $(dirname "$0")/.. && pwd)
DOTENV_FILE="${REPO_ROOT}/.env"
. "${REPO_ROOT}/scripts/utilities.sh"

if [ ! -f "${DOTENV_FILE}" ]; then
  error ".env file not found at ${DOTENV_FILE}. Please follow the instructions in ${REPO_ROOT}/README.md to create one."
  exit 1
fi

. "${DOTENV_FILE}"

### Ensure .env file contains credentials.
if [ -z "${STRIPE_SECRET_KEY}" ]; then
  error ".env file exists, but does not set the STRIPE_SECRET_KEY property."
  exit 1
fi

### Helper Functions
function create_payment_method() {
  stripe_curl https://api.stripe.com/v1/payment_methods \
    -X POST \
    -d type=card \
    -d "card[number]=4242424242424242" \
    -d "card[exp_month]=12" \
    -d "card[exp_year]=2040" \
    -d "card[cvc]=123"
}

function detach_payment_method() {
  local PAYMENT_METHOD_ID=$1
  stripe_curl -X POST "https://api.stripe.com/v1/payment_methods/${PAYMENT_METHOD_ID}/detach"
}

function delete_subscription() {
  local SUBSCRIPTION_ID=$1
  stripe_curl -X DELETE "https://api.stripe.com/v1/subscriptions/${SUBSCRIPTION_ID}"
}


# invoke bootstrap
"${REPO_ROOT}/scripts/bootstrap.sh"

FAILURES=0

function run_tests_on_server() {
  local server="$1"
  cd "$server"
  SERVER_NAME=$(basename "$server")

  if [ -f ./build.sh ]; then
    info "Building $SERVER_NAME server"
    ./build.sh
    if [ $? -gt 0 ]; then
      error "Could not build $SERVER_NAME server. Skipping..."
      FAILURES=$(( FAILURES + 1 ))
      return
    fi
  fi
  if [ -f ./start.sh ]; then
    info "Starting $SERVER_NAME server"
    ./start.sh
    if [ $? -gt 0 ]; then
      error "Could not start $SERVER_NAME server. Skipping."
      FAILURES=$(( FAILURES + 1 ))
    fi
  else
    warn "No start script for $SERVER_NAME. Skipping."
    return
  fi

  # create payment method for tests
  PAYMENT_METHOD_RESULT=$(create_payment_method)

  describe_api_result "${PAYMENT_METHOD_RESULT}" "create payment method"
  PAYMENT_METHOD_ID=$(echo "${PAYMENT_METHOD_RESULT}" | jq -e --raw-output .id)
  CARD_ID=$(echo "${PAYMENT_METHOD_RESULT}" | jq -e --raw-output .card)


  payment_method_status=$?
  if [[ $payment_method_status -gt 0 ]]; then
    error "Could not create a payment method for tests. Inspect the error result above. Exiting."
  fi

  # declare create customer json
  read -d '' CREATE_CUSTOMER_JSON << EOF
  {
    "email": "test@example.com",
    "payment_method": "$PAYMENT_METHOD_ID",
    "plan_ids": ["stripe-example-bear", "stripe-example-tiger"]
  }
EOF


  ### fetch api key
  SERVER_KEY=$(curl --silent --max-time 3 http://localhost:4242/public-key | jq --raw-output .publicKey)
  if [[ ! $SERVER_KEY = $STRIPE_PUBLISHABLE_KEY ]]; then
    error "$SERVER_NAME: /public-key did not serve correct credentials."
    FAILURES=$(( FAILURES + 1 ))
    debug "${RESULT}"
  fi

  ### create customer
  RESULT=$(echo ${CREATE_CUSTOMER_JSON} | curl --max-time 20 --silent -d @- -H "Content-Type: application/json" http://localhost:4242/create-customer)
  SUBSCRIPTION_ID=$(echo "${RESULT}" | jq --raw-output .id)
  debug "${RESULT}"
  describe_api_result "${RESULT}" "$SERVER_NAME: create-customer API"
  echo "${RESULT}" | jq -e .error > /dev/null
  if [ $? -eq 0 ]; then
    error "$SERVER_NAME: /create-customer returned an error: $(echo "${RESULT}" | jq .error)"
    FAILURES=$(( FAILURES + 1))
  fi

  ### fetch subscription
  read -d '' GET_SUBSCRIPTION_JSON << EOF
{
  "subscriptionId": "${SUBSCRIPTION_ID}"
}
EOF

  RESULT=$(echo "${GET_SUBSCRIPTION_JSON}" | curl --max-time 10 --silent -d @- -H "Content-Type: application/json" http://localhost:4242/subscription)
  describe_api_result "${RESULT}" "$SERVER_NAME: fetch subscription"
  echo "${RESULT}" | jq -e .error > /dev/null
  if [ $? -eq 0 ]; then
    error "$SERVER_NAME: /subscription returned an error: $(echo "${RESULT}" | jq .error)"
    FAILURES=$(( FAILURES + 1))
  fi

  ### cleanup subscription
  describe_api_result "$(delete_subscription "${SUBSCRIPTION_ID}")" "$SERVER_NAME: cleanup subscription"

  ## shutdown server
  if [ -f ./stop.sh ]; then
    info "Stopping $SERVER_NAME server"
    ./stop.sh
  fi

  describe_api_result "$(detach_payment_method "${PAYMENT_METHOD_ID}")" "cleanup payment method"
}

function run_tests_on_all_servers() {
  for server in "${REPO_ROOT}"/server/*; do
    ## build and run server in background
    if [[ ! -d "$server" ]]; then
      continue
    fi

    run_tests_on_server "$server"
  done
}

if [[ -d "$1" ]]; then
  info "Running tests for $1"
  run_tests_on_server "$1"
else
  run_tests_on_all_servers
fi

# invoke cleanup
"${REPO_ROOT}/scripts/cleanup.sh"

if [[ ${FAILURES} -gt 0 ]]; then
  error "There were errors validating ${FAILURES} server implementation(s). Please review output for more details."
fi

exit $FAILURES






