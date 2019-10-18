#! /usr/bin/env python3.6

"""
server.py
Stripe Recipe.
Python 3.6 or newer required.
"""

import stripe
import json
import os

from flask import Flask, render_template, jsonify, request, send_from_directory
from dotenv import load_dotenv, find_dotenv
from pathlib import Path

static_dir = f'{os.path.abspath(os.path.join(__file__ ,"../../../client"))}'
app = Flask(__name__, static_folder=static_dir, static_url_path="", template_folder=static_dir)

def load_plans():
    plansFilePath = os.getenv('PLANS_FILE_LOCATION')
    plansJson = Path(plansFilePath).read_text()
    plans = json.loads(plansJson)
    return { plan["planId"]: plan for plan in plans }

plans = load_plans()

# Setup Stripe python client library
load_dotenv(find_dotenv())
stripe.api_key = os.getenv('STRIPE_SECRET_KEY')
stripe.api_version = os.getenv('STRIPE_API_VERSION')

@app.route('/', methods=['GET'])
def get_index():
    return render_template('index.html')

# This endpoint is used by client in client/script.js
# Returns relevant data about plans using the Stripe API
@app.route('/bootstrap', methods=['GET'])
def get_boostrap():
    return jsonify(
        publicKey=os.getenv('STRIPE_PUBLIC_KEY'),
        plans=[plan for plan in plans.values()]
    )

@app.route('/create-customer', methods=['POST'])
def create_customer():
    # Reads application/json and returns a response
    data = json.loads(request.data)
    paymentMethod = data['payment_method']
    planIds = data['plan_ids']
    couponId = os.getenv('COUPON_ID')

    # Here we make sure the planIds passed by client are consistent with those
    # we want to allow.
    # ** Note that our API does not support combining plans with different billing cycles
    # or currencies in one subscription. You may also want to check consistency in those
    # here **
    if (any([planId for planId in planIds if planId in plans])):
        return "invalid plan id selected", 400

    # In this example, we apply the coupon if the number of plans purchased by
    # passes the threshold.
    minPlansForDiscount = 2
    coupon = couponId if len(planIds) >= minPlansForDiscount else None
    try:
        # This creates a new Customer and attaches the PaymentMethod in one API call.
        # At this point, associate the ID of the Customer object with your
        # own internal representation of a customer, if you have one.
        customer = stripe.Customer.create(
            payment_method=paymentMethod, 
            email=data['email'],
            invoice_settings={
                'default_payment_method':paymentMethod
            }
        )

        # Subscribe the user to the subscription created
        subscription = stripe.Subscription.create(
            customer=customer.id,
            items=[{"plan": planId} for planId in planIds],
            expand=["latest_invoice.payment_intent"],
            coupon=coupon
        )
        return jsonify(subscription)
    except Exception as e:
        return jsonify(e), 403

@app.route('/subscription', methods=['POST'])
def getSubscription():
    # Reads application/json and returns a response
    data = json.loads(request.data)
    try:
        subscription = stripe.Subscription.retrieve(data['subscriptionId'])
        return jsonify(subscription)
    except Exception as e:
        return jsonify(e), 403

@app.route('/webhook', methods=['POST'])
def webhook_received():
    # You can use webhooks to receive information about asynchronous payment events.
    # For more about our webhook events check out https://stripe.com/docs/webhooks.
    webhook_secret = os.getenv('STRIPE_WEBHOOK_SECRET')
    request_data = json.loads(request.data)

    if webhook_secret:
        # Retrieve the event by verifying the signature using the raw body and secret if webhook signing is configured.
        signature = request.headers.get('stripe-signature')
        try:
            event = stripe.Webhook.construct_event(
                payload=request.data, sig_header=signature, secret=webhook_secret)
            data = event['data']
        except Exception as e:
            return e
        # Get the type of webhook event sent - used to check the status of PaymentIntents.
        event_type = event['type']
    else:
        data = request_data['data']
        event_type = request_data['type']

    data_object = data['object']
    
    if event_type == 'customer.created':
        print(data)

    if event_type == 'customer.updated':
        print(data)

    if event_type == 'invoice.upcoming':
        print(data)

    if event_type == 'invoice.created':
        print(data)

    if event_type == 'invoice.finalized':
        print(data)

    if event_type == 'invoice.payment_succeeded':
        print(data)

    if event_type == 'invoice.payment_failed':
        print(data)

    if event_type == 'customer.subscription.created':
        print(data)

    return jsonify({'status': 'success'})


if __name__== '__main__':
    app.run(port=4242)
