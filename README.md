# Stripe Billing subscribing a customer to multiple products

This sample shows how to create a customer and subscribe them to multiple flat rate plans with
[Stripe Billing](https://stripe.com/billing). For step by step directions showing how to
implement this, use the [Stripe Billing quickstart](https://stripe.com/docs/billing/quickstart) (you may also find [Working with Multiple Plans per Subscription](https://stripe.com/docs/billing/subscriptions/multiplan) helpful).

![Purchase demo](./petting-zoo-demo.gif)

# Demo

Web: See the sample [live](https://bio87.sse.codesandbox.io/) in test mode or [fork](https://codesandbox.io/s/stripe-billing-multiplan-subscription-quickstart-zph6v) the Node implementation on CodeSandbox.
iOS and Android: Clone this repo and run the sample server and app locally (see below).

Features:

- Collect card details 💳
- Subscribe a customer to multiple products in Stripe Billing 🦁🐯🐻
- Apply a discount when a customer purchases more than one product 💰

## How to run locally

This sample includes [5 server implementations](server/README.md) in our most popular languages. 

You will need a Stripe account with its own set of [API keys](https://stripe.com/docs/development#api-keys), as well as a .env file updated with your account's keys.

You will also need to [add your phone number to your Stripe account](https://dashboard.stripe.com/phone-verification) in order to use the provided scripts (required in order to pass a credit card number directly to the API through curl).

Follow the steps below to run locally.

**1. Clone and configure the sample**

The Stripe CLI is the fastest way to clone and configure a sample to run locally. 

**Using the Stripe CLI**

If you haven't already installed the CLI, follow the [installation steps](https://github.com/stripe/stripe-cli#installation) in the project README. The CLI is useful for cloning samples and locally testing webhooks and Stripe integrations.

In your terminal shell, run the Stripe CLI command to clone the sample:

```
stripe samples create multiple-plan-subscriptions
```

The CLI will walk you through picking your integration type, server and client languages, and configuring your .env config file with your Stripe API keys. 

**Installing and cloning manually**

If you do not want to use the Stripe CLI, you can manually clone and configure the sample yourself:

```
git clone https://github.com/stripe-samples/charging-for-multiple-plan-subscriptions
```

Copy the .env.example file into a file named .env in the folder of the server you want to use. For example:

```
cp .env.example server/node/.env
```

Go to the Stripe [developer dashboard](https://stripe.com/docs/development#api-keys) to find your API keys.

```
STRIPE_PUBLISHABLE_KEY=<replace-with-your-publishable-key>
STRIPE_SECRET_KEY=<replace-with-your-secret-key>
```

`CLIENT_DIR` tells the server where to the client files are located and does not need to be modified unless you move the server files.

**2. Follow the server instructions on how to run:**

Pick the server language you want and follow the instructions in the server folder README on how to run.

For example, if you want to run the Node server in `using-webhooks`:

```
cd server/node # there's a README in this folder with instructions
npm install
npm start
```

After that, run the bootstrap script to create the billing objects referenced by the client and server within your account (uses the provided API keys from your .env file):

```
./scripts/bootstrap.sh
```

When finished, run the cleanup script to delete the generated objects:

```
./scripts/cleanup.sh
```

## FAQ

Q: Why did you pick these frameworks?

A: We chose the most minimal framework to convey the key Stripe calls and concepts you need to understand. These demos are meant as an educational tool that helps you roadmap how to integrate Stripe within your own system independent of the framework.

Q: Can you show me how to build X?

A: We are always looking for new sample ideas, please email dev-samples@stripe.com with your suggestion!

## Author(s)

- [@abhishek-stripe](https://github.com/abhishek-stripe)
- [@camilo-stripe](https://github.com/camilo-stripe)
- [@ctrudeau-stripe](https://twitter.com/trudeaucj)
- [@dylanw-stripe](https://github.com/dylanw-stripe)
- [@markt-stripe](https://github.com/markt-stripe)
- [@seanfitz-stripe](https://github.com/seanfitz-stripe)
