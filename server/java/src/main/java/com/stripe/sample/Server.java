package com.stripe.sample;

import static spark.Spark.exception;
import static spark.Spark.get;
import static spark.Spark.port;
import static spark.Spark.post;
import static spark.Spark.staticFiles;

import java.nio.file.Paths;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.annotations.SerializedName;
import com.stripe.Stripe;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Customer;
import com.stripe.model.Event;
import com.stripe.model.EventDataObjectDeserializer;
import com.stripe.model.Price;
import com.stripe.model.PriceCollection;
import com.stripe.model.StripeObject;
import com.stripe.model.Subscription;
import com.stripe.net.Webhook;
import com.stripe.param.CustomerCreateParams;
import com.stripe.param.PriceListParams;
import com.stripe.param.SubscriptionCreateParams;

import io.github.cdimascio.dotenv.Dotenv;

public class Server {
    private static Gson gson = new Gson();

    static class CreatePaymentBody {
        @SerializedName("payment_method")
        String paymentMethod;
        @SerializedName("email")
        String email;
        @SerializedName("price_ids")
        String[] priceIds;

        public String getPaymentMethod() {
            return paymentMethod;
        }

        public String getEmail() {
            return email;
        }
    }

    static class CreateSubscriptionBody {
        @SerializedName("subscriptionId")
        String subscriptionId;

        public String getSubscriptionId() {
            return subscriptionId;
        }
    }

    public static void main(String[] args) {
        port(4242);
        Dotenv dotenv = Dotenv.load();
        Stripe.apiKey = dotenv.get("STRIPE_SECRET_KEY");

        staticFiles.externalLocation(
                Paths.get(Paths.get("").toAbsolutePath().toString(), dotenv.get("STATIC_DIR")).normalize().toString());

        get("/setup-page", (request, response) -> {
            response.type("application/json");

            List<String> animals = Arrays.asList(dotenv.get("ANIMALS").split(","));
            List<String> lookup_keys = animals.stream()
                .map(s -> s.concat("-monthly-usd"))
                .collect(Collectors.toList());

            PriceListParams params = PriceListParams.builder()
                .addAllLookupKeys(lookup_keys)
                .addAllExpand(Arrays.asList("data.product"))
                .build();

            PriceCollection prices = Price.list(params);

            JsonArray products = new JsonArray();
            for (Price price : prices.getData()) {
                JsonObject product = new JsonObject();
                JsonObject priceInfo = new JsonObject();
                priceInfo.addProperty("id", price.getId());
                priceInfo.addProperty("unit_amount", price.getUnitAmount());
                product.add("price", priceInfo);
                product.addProperty("title", price.getProductObject().getMetadata().get("title"));
                product.addProperty("emoji", price.getProductObject().getMetadata().get("emoji"));
                products.add(product);
            }

            JsonObject payload = new JsonObject();
            payload.addProperty("publicKey", dotenv.get("STRIPE_PUBLISHABLE_KEY"));
            payload.addProperty("minProductsForDiscount", dotenv.get("MIN_PRODUCTS_FOR_DISCOUNT"));
            payload.addProperty("discountFactor", dotenv.get("DISCOUNT_FACTOR"));
            payload.add("products", products);

            return payload.toString();
        });

        post("/create-customer", (request, response) -> {
            response.type("application/json");

            CreatePaymentBody postBody = gson.fromJson(request.body(), CreatePaymentBody.class);

            CustomerCreateParams customerParams =
              CustomerCreateParams.builder()
                .setPaymentMethod(postBody.getPaymentMethod())
                .setEmail(postBody.getEmail())
                .setInvoiceSettings(
                  CustomerCreateParams.InvoiceSettings.builder()
                    .setDefaultPaymentMethod(postBody.getPaymentMethod())
                    .build())
                .build();

            Customer customer = Customer.create(customerParams);

            // Build the collection of products based on what the customer choose
            List<SubscriptionCreateParams.Item> items = new ArrayList<SubscriptionCreateParams.Item>();
            for (String priceId : postBody.priceIds) {
                items.add(SubscriptionCreateParams.Item.builder()
                    .setPrice(priceId)
                    .build());
            }

            String couponId = null;
            if (items.size() >= Integer.parseInt(dotenv.get("MIN_PRODUCTS_FOR_DISCOUNT")))
            {
              couponId = dotenv.get("COUPON_ID");
            }

            //Subscribe the customer
            SubscriptionCreateParams subscriptionParams =
              SubscriptionCreateParams.builder()
                .setCustomer(customer.getId())
                .setCoupon(couponId)
                .addAllExpand(Arrays.asList("latest_invoice.payment_intent"))
                .addAllItem(items)
                .build();

            Subscription subscription = Subscription.create(subscriptionParams);
            return subscription.toJson();
        });

        post("/subscription", (request, response) -> {
            response.type("application/json");

            CreateSubscriptionBody postBody = gson.fromJson(request.body(), CreateSubscriptionBody.class);
            return Subscription.retrieve(postBody.getSubscriptionId()).toJson();
        });

        post("/webhook", (request, response) -> {
            String payload = request.body();
            String sigHeader = request.headers("Stripe-Signature");
            String endpointSecret = dotenv.get("STRIPE_WEBHOOK_SECRET");
            Event event = null;

            try {
                event = Webhook.constructEvent(payload, sigHeader, endpointSecret);
            } catch (SignatureVerificationException e) {
                // Invalid signature
                response.status(400);
                return "";
            }

            // Deserialize the nested object inside the event
            EventDataObjectDeserializer dataObjectDeserializer = event.getDataObjectDeserializer();
            StripeObject stripeObject = null;
            if (dataObjectDeserializer.getObject().isPresent()) {
                stripeObject = dataObjectDeserializer.getObject().get();
            } else {
                // Deserialization failed, probably due to an API version mismatch.
                // Refer to the Javadoc documentation on `EventDataObjectDeserializer` for
                // instructions on how to handle this case, or return an error here.
            }

            switch (event.getType()) {
            case "customer.created":
                // Customer customer = (Customer) stripeObject;
                // System.out.println(customer.toJson());
                break;
            case "customer.updated":
                // Customer customer = (Customer) stripeObject;
                // System.out.println(customer.toJson());
                break;
            case "invoice.upcoming":
                // Invoice invoice = (Invoice) stripeObject;
                // System.out.println(invoice.toJson());
                break;
            case "invoice.created":
                // Invoice invoice = (Invoice) stripeObject;
                // System.out.println(invoice.toJson());
                break;
            case "invoice.finalized":
                // Invoice invoice = (Invoice) stripeObject;
                // System.out.println(invoice.toJson());
                break;
            case "invoice.payment_succeeded":
                // Invoice invoice = (Invoice) stripeObject;
                // System.out.println(invoice.toJson());
                break;
            case "invoice.payment_failed":
                // Invoice invoice = (Invoice) stripeObject;
                // System.out.println(invoice.toJson());
                break;
            case "customer.subscription.created":
                Subscription subscription = (Subscription) stripeObject;
                System.out.println(subscription.toJson());
                break;
            default:
                // Unexpected event type
                response.status(400);
                return "";
            }

            response.status(200);
            return "";
        });
    }
}