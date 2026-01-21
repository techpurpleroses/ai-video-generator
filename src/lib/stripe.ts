import "server-only";

import Stripe from "stripe";

let cachedStripe: Stripe | null = null;

export function getStripeClient() {
  const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
  if (!stripeSecretKey) {
    return null;
  }
  if (!cachedStripe) {
    cachedStripe = new Stripe(stripeSecretKey, {
      apiVersion: "2024-04-10",
    });
  }
  return cachedStripe;
}
