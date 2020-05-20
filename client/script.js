var stripe;
var allProducts = {};
var minProductsForDiscount;
var discountFactor;

var stripeElements = function(publicKey) {
  stripe = Stripe(publicKey);
  var elements = stripe.elements();

  // Element styles
  var style = {
    base: {
      fontSize: '16px',
      color: '#32325d',
      fontFamily:
        '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif',
      fontSmoothing: 'antialiased',
      '::placeholder': {
        color: 'rgba(0,0,0,0.4)'
      }
    }
  };

  var card = elements.create('card', { style: style });

  card.mount('#card-element');

  // Element focus ring
  card.on('focus', function() {
    var el = document.getElementById('card-element');
    el.classList.add('focused');
  });

  card.on('blur', function() {
    var el = document.getElementById('card-element');
    el.classList.remove('focused');
  });

  document.querySelector('#submit').addEventListener('click', function(evt) {
    evt.preventDefault();
    document.querySelector('#submit').disabled = true;
    // Initiate payment
    pay(stripe, card);
  });
};

var pay = function(stripe, card) {
  var cardholderEmail = document.querySelector('#email').value;
  stripe
    .createPaymentMethod('card', card, {
      billing_details: {
        email: cardholderEmail
      }
    })
    .then(function(result) {
      if (result.error) {
        document.querySelector('#submit').disabled = false;
        // The card was declined (i.e. insufficient funds, card has expired, etc)
        var errorMsg = document.querySelector('.sr-field-error');
        errorMsg.textContent = result.error.message;
        setTimeout(function() {
          errorMsg.textContent = '';
        }, 4000);
      } else {
        createCustomer(result.paymentMethod.id, cardholderEmail);
      }
    });
};

var getSelectedProducts = function() {
  return Object.values(allProducts).filter(product => product.selected);
};

var onSelectionChanged = function() {
  var selectedProducts = getSelectedProducts();
  updateSummaryTable();
  var showPaymentForm = selectedProducts.length == 0;
  var paymentFormElts = document.querySelectorAll('.sr-payment-form');
  if (showPaymentForm) {
    paymentFormElts.forEach(function(elt) {
      elt.classList.add('hidden');
    });
  } else {
    paymentFormElts.forEach(function(elt) {
      elt.classList.remove('hidden');
    });
  }
};

var updateSummaryTable = function() {
  var computeSubtotal = function() {
    var selectedProducts = getSelectedProducts();
    return selectedProducts
      .map(product => product.price.unit_amount)
      .reduce((product1, product2) => product1 + product2, 0);
  };

  var computeDiscountPercent = function() {
    var selectedProducts = getSelectedProducts();
    var eligibleForDiscount = selectedProducts.length >= minProductsForDiscount;
    return eligibleForDiscount ? discountFactor : 0;
  };

  var selectedProducts = getSelectedProducts();
  var discountPercent = computeDiscountPercent();
  var subtotal = computeSubtotal();
  var discount = discountPercent * subtotal;
  var total = subtotal - discount;

  var orderSummary = document.getElementById('summary-table');
  if (orderSummary) {
    var buildOrderSummaryRow = function(rowClass, desc, amountCents) {
        return `
          <div class="summary-title ${rowClass}">${capitalize(desc)}</div>
          <div class="summary-price ${rowClass}">${getPriceDollars(amountCents)}</div>
        `;
    };
    orderSummary.innerHTML = '';
    preface = '';
    if (selectedProducts.length == 0) {
      preface = 'No animals selected';
    } else {
      preface = 'Prices listed correspond to a recurrent monthly susbcription';

      for (var i = 0; i < selectedProducts.length; i++) {
        orderSummary.innerHTML += buildOrderSummaryRow('summary-product', selectedProducts[i].title, selectedProducts[i].price.unit_amount);
      }
      if (discount>0){
        orderSummary.innerHTML += buildOrderSummaryRow('summary-subtotal', 'Subtotal', subtotal);
        orderSummary.innerHTML += buildOrderSummaryRow('summary-discount', 'Discount', discount);
      }
      orderSummary.innerHTML += buildOrderSummaryRow('summary-total', 'Total', total);
    }
    document.getElementById('summary-preface').innerHTML = preface;

  }
};

function capitalize(name){
  return name.charAt(0).toUpperCase() + name.slice(1);
}

function getPriceDollars(price, recurringBy=undefined) {
  var pricePart = '$' + Math.round(price / 100.0);
  if (recurringBy===undefined){
    return pricePart;
  }
  else{
    return pricePart + '/' + recurringBy;
  }
}

function createCustomer(paymentMethod, cardholderEmail) {
  return fetch('/create-customer', {
    method: 'post',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email: cardholderEmail,
      payment_method: paymentMethod,
      price_ids: getSelectedProducts().map(product => product.price.id)
    })
  })
    .then(function(response) {
      return response.json();
    })
    .then(function(subscription) {
      if (subscription.error) {
        orderComplete(subscription);
      } else {
        handleSubscription(subscription);
      }
    });
}

function handleSubscription(subscription) {
  if (
    subscription &&
    subscription.latest_invoice &&
    subscription.latest_invoice.payment_intent &&
    subscription.latest_invoice.payment_intent.status === 'requires_action'
  ) {
    stripe
      .confirmCardPayment(
        subscription.latest_invoice.payment_intent.client_secret
      )
      .then(function(result) {
        confirmSubscription(subscription.id);
      });
  } else if (subscription) {
    confirmSubscription(subscription.id);
    orderComplete(subscription);
  } else {
    orderComplete(subscription);
  }
}

function confirmSubscription(subscriptionId) {
  return fetch('/subscription', {
    method: 'post',
    headers: {
      'Content-type': 'application/json'
    },
    body: JSON.stringify({
      subscriptionId: subscriptionId
    })
  })
    .then(function(response) {
      return response.json();
    })
    .then(function(subscription) {
      orderComplete(subscription);
    });
}

function init() {
  return fetch('/setup-page', {
    method: 'get',
    headers: {
      'Content-Type': 'application/json'
    }
  })
    .then(function(response) {
      return response.json();
    })
    .then(function(json) {
      stripeElements(json.publicKey);
      coupon = json.coupon;
      minProductsForDiscount = json.minProductsForDiscount;
      discountFactor = json.discountFactor;
      products = json.products;
      products.forEach(function(product) {
        product.selected = false;
        allProducts[product.price.id] = product;
      });
      generateHtmlForPricingPage();
      onSelectionChanged();
    });
}

init();


function generateHtmlForPricingPage(){
  function generateHtmlForSingleProduct(id, animal, price, emoji){
    result = `
        <div class="sr-animal">
          <div class="sr-animal-emoji"
            id=\'${id}\'
            onclick="toggleAnimal(\'${id}\')">
              ${emoji}
          </div>
          <div class="sr-animal-text">${capitalize(animal)}</div>
          <div class="sr-animal-text">${getPriceDollars(price, 'month')}</div>
        </div>
      `;
    return result;
  }
  var html = '';
  Object.values(allProducts).forEach((product) => {
    html += generateHtmlForSingleProduct(product.price.id, product.title, product.price.unit_amount, product.emoji);
  });

  document.getElementById('sr-animals').innerHTML += html;
}

function toggleAnimal(id){
  allProducts[id].selected = !allProducts[id].selected;
  var productElt = document.getElementById(id);
  if (allProducts[id].selected) {
    productElt.classList.add('selected');
  }
  else {
    productElt.classList.remove('selected');
  }

  onSelectionChanged();
}

/* ------- Post-payment helpers ------- */

/* Shows a success / error message when the payment is complete */
var orderComplete = function(subscription) {
  var subscriptionJson = JSON.stringify(subscription, null, 2);
  document.querySelectorAll('.payment-view').forEach(function(view) {
    view.classList.add('hidden');
  });
  document.querySelectorAll('.completed-view').forEach(function(view) {
    view.classList.remove('hidden');
  });
  var orderStatus = document.getElementById('order-status');
  if (subscription.hasOwnProperty('error')) {
    orderStatus.textContent = 'Error creating subscription';
    orderStatus.style.color = 'red';
  } else {
    orderStatus.textContent = 'Your subscription is ' + subscription.status;
    orderStatus.style.color = 'black';
  }
  document.getElementById('sr-animals').classList.add('hidden');
  document.getElementById('request-json').textContent = subscriptionJson;
};
