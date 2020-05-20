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

# Setup Stripe python client library
load_dotenv(find_dotenv())
stripe.api_key = os.getenv('STRIPE_SECRET_KEY')
stripe.api_version = os.getenv('STRIPE_API_VERSION')

static_dir = str(os.path.abspath(os.path.join(
    __file__, "..", os.getenv("STATIC_DIR"))))
app = Flask(__name__, static_folder=static_dir,
            static_url_path="", template_folder=static_dir)

MIN_PLANS_FOR_DISCOUNT = 2

@app.route('/', methods=['GET'])
def get_index():
    return render_template('index.html')

# This endpoint is used by client in client/script.js
# Returns relevant data about plans using the Stripe API
@app.route('/setup-page', methods=['GET'])
def get_setup_page():
    try:
        animals = os.getenv('ANIMALS').split(",")
        lookup_keys = []
        for animal in animals:
          lookup_keys.append(animal + '-monthly-usd')

        prices = stripe.Price.list(lookup_keys=lookup_keys, expand=['data.product'])

        products = []
        for price in prices:
            product = {
              'price': { 'id': price['id'], 'unit_amount': price['unit_amount']},
              'title': price['product']['metadata']['title'],
              "emoji": price['product']['metadata']['emoji']
            }
            products.append(product)

        # returns config information that is used by the client JavaScript to display the page. 
        return jsonify({
            'publicKey': os.getenv('STRIPE_PUBLISHABLE_KEY'),
            'discountFactor': os.getenv('DISCOUNT_FACTOR'),
            'minProductsForDiscount': os.getenv('MIN_PRODUCTS_FOR_DISCOUNT'),
            'products': products
        })
    except Exception as e:
        return jsonify(error=str(e)), 403

@app.route('/create-customer', methods=['POST'])
def create_customer():
    # Reads application/json and returns a response
    data = json.loads(request.data)
    paymentMethod = data['payment_method']
    priceIds = data['price_ids']

    # This creates a new Customer and attaches the PaymentMethod in one API call.
    # At this point, associate the ID of the Customer object with your
    # own internal representation of a customer, if you have one.
    customer = stripe.Customer.create(
        payment_method=paymentMethod,
        email=data['email'],
        invoice_settings={
            'default_payment_method': paymentMethod
        }
    )

    # In this example, we apply the coupon if the number of plans purchased
    # meets or exceeds the threshold.
    eligibleForDiscount = len(priceIds) >= int(os.getenv('MIN_PRODUCTS_FOR_DISCOUNT'))
    coupon = os.getenv('COUPON_ID') if eligibleForDiscount else None

    # Subscribe the user to the subscription created
    subscription = stripe.Subscription.create(
        customer=customer.id,
        items=[{"price": priceId} for priceId in priceIds],
        expand=["latest_invoice.payment_intent"],
        coupon=coupon
    )
    return jsonify(subscription)


@app.route('/subscription', methods=['POST'])
def getSubscription():
    # Reads application/json and returns a response
    data = json.loads(request.data)
    subscription = stripe.Subscription.retrieve(data['subscriptionId'])
    return jsonify(subscription)

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

@app.errorhandler(Exception)
def wrap_error(e):
    # try to return error message from the Stripe API first, otherwise fall back to repr
    if (hasattr(e, 'json_body')
        and 'error' in e.json_body
        and 'message' in e.json_body['error']):
        return jsonify({ 'error': { 'message': e.json_body['error']['message'] } }), 500

    return jsonify({ 'error': { 'message': repr(e) }})

if __name__ == '__main__':
    app.run(port=4242)
