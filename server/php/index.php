<?php
use Slim\Http\Request;
use Slim\Http\Response;
use Stripe\Stripe;
require 'vendor/autoload.php';


$dotenv = Dotenv\Dotenv::create(__DIR__);
$dotenv->load();

require './config.php';

$app = new \Slim\App;

// Instantiate the logger as a dependency
$container = $app->getContainer();
$container['logger'] = function ($c) {
  $settings = $c->get('settings')['logger'];
  $logger = new Monolog\Logger($settings['name']);
  $logger->pushProcessor(new Monolog\Processor\UidProcessor());
  $logger->pushHandler(new Monolog\Handler\StreamHandler(__DIR__ . '/logs/app.log', \Monolog\Logger::DEBUG));
  return $logger;
};

$container['errorHandler'] = function ($c) {
  return function ($request, $response, $exception) use ($c) {
    // try to return error message from Stripe API first, otherwise fall back to the full error
    if (property_exists($exception, 'jsonBody')
      && isset($exception->jsonBody['error'])
      && isset($exception->jsonBody['error']['message'])) {
        return $response->withStatus(500)
          ->withHeader('Content-Type', 'application/json')
          ->withJson([ 'error' => [ 'message' => $exception->jsonBody['error']['message'] ]]);
    }

    return $response->withStatus(500)
      ->withHeader('Content-Type', 'application/json')
      ->withJson([ 'error' => [ 'message' => strval($exception) ]]);
  };
};

$app->add(function ($request, $response, $next) {
  Stripe::setApiKey(getenv('STRIPE_SECRET_KEY'));
  return $next($request, $response);
});

$app->get('/', function (Request $request, Response $response, array $args) {   
  // Display checkout page
  return $response->write(file_get_contents('../../client/index.html'));
});

$app->get('/setup-page', function (Request $request, Response $response, array $args) {
  $animals = explode(',', getenv('ANIMALS'));
  $lookup_keys = [];

  foreach($animals as $animal)
  {
    array_push($lookup_keys, $animal . "-monthly-usd");
  }

  $prices = \Stripe\Price::all([
    "lookup_keys" => $lookup_keys,
    "expand" =>['data.product']
  ]);

  $products = [];

  foreach($prices as $price)
  {

    $logger->info('product ' . print_r($price['product']['metadata'], TRUE));
    $product = [
      'price' => [
        'id' => $price['id'],
        'unit_amount' => $price['unit_amount']
      ],
      'title' => $price['product']['metadata']['title'],
      'emoji' => $price['product']['metadata']['emoji']
    ];
    array_push($products, $product);
  }


  // Send publishable key and other info to client
  return $response->withJson(array(
    'publicKey' => getenv('STRIPE_PUBLISHABLE_KEY'),
    'minProductsForDiscount' => getenv('MIN_PRODUCTS_FOR_DISCOUNT'),
    'discountFactor' => getenv('DISCOUNT_FACTOR'),
    'products' => $products
    ));
});

$app->post('/create-customer', function (Request $request, Response $response, array $args) {
  $body = json_decode($request->getBody());
  
  # This creates a new Customer and attaches the PaymentMethod in one API call.
  # At this point, associate the ID of the Customer object with your
  # own internal representation of a customer, if you have one. 
  $customer = \Stripe\Customer::create([
    "payment_method" => $body->payment_method,
    "email" => $body->email, 
    "invoice_settings" => [
      "default_payment_method" => $body->payment_method
    ]
  ]);

  $eligibleForDiscount = count($body->price_ids) >= intval(getenv('MIN_PLANS_FOR_DISCOUNT'));
  $couponId = $eligibleForDiscount ? getenv('COUPON_ID') : null;
  $subscription = \Stripe\Subscription::create([
    "customer" => $customer['id'],
    "items" => array_map(function ($priceId) { return [ "price" => $priceId ]; }, $body->price_ids),
    "expand" => ['latest_invoice.payment_intent'],
    "coupon" => $couponId
  ]);

  return $response->withJson($subscription);
});

$app->post('/subscription', function (Request $request, Response $response, array $args) {  
  $body = json_decode($request->getBody());

  $subscription = \Stripe\Subscription::retrieve($body->subscriptionId);

  return $response->withJson($subscription);
});


$app->post('/webhook', function(Request $request, Response $response) {
  $logger = $this->get('logger');
  $event = $request->getParsedBody();
  // Parse the message body (and check the signature if possible)
  $webhookSecret = getenv('STRIPE_WEBHOOK_SECRET');
  if ($webhookSecret) {
    try {
      $event = \Stripe\Webhook::constructEvent(
        $request->getBody(),
        $request->getHeaderLine('stripe-signature'),
        $webhookSecret
      );
    } catch (\Exception $e) {
      return $response->withJson([ 'error' => $e->getMessage() ])->withStatus(403);
    }
  } else {
    $event = $request->getParsedBody();
  }
  $type = $event['type'];
  $object = $event['data']['object'];

  // Handle the event
  // Review important events for Billing webhooks
  // https://stripe.com/docs/billing/webhooks
  // Remove comment to see the various objects sent for this sample
  switch ($type) {
    case 'customer.created':
      $logger->info('🔔  Webhook received! ' . $object);
      break;
    case 'customer.updated':
      $logger->info('🔔  Webhook received! ' . $object);
      break;
    case 'invoice.upcoming':
      $logger->info('🔔  Webhook received! ' . $object);
      break;
    case 'invoice.created':
      $logger->info('🔔  Webhook received! ' . $object);
      break;
    case 'invoice.finalized':
      $logger->info('🔔  Webhook received! ' . $object);
      break;
    case 'invoice.payment_succeeded':
      $logger->info('🔔  Webhook received! ' . $object);
      break;
    case 'invoice.payment_failed':
      $logger->info('🔔  Webhook received! ' . $object);
      break;
    case 'customer.subscription.created':
      $logger->info('🔔  Webhook received! ' . $object);
      break;
    // ... handle other event types
    default:
      // Unexpected event type
      return $response->withStatus(400);
  }

  return $response->withJson([ 'status' => 'success' ])->withStatus(200);
});

$app->run();
