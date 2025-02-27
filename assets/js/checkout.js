let elements;

import { loadStripe } from "@stripe/stripe-js/pure";

export const InitCheckout = {
  async mounted() {
    stripe = await loadStripe(
      "pk_test_51QFDv6ENoY5GyA7jeRaxuUSGKGzDLHEu7uRfVgbcAYabj5oepxaZMQ8rNakOQTD6OibKHaxLgUeZqITqtoRZYz2L00t62OGcoq",
    );

    init(this.el);
  },
};

const init = (form) => {
  const clientSecret = form.dataset.secret;
  const appearance = { theme: "stripe" };

  elements = stripe.elements({ appearance, clientSecret });

  const paymentElementOptions = {
    layout: "tabs",
  };

  const paymentElement = elements.create("payment", paymentElementOptions);
  paymentElement.mount("#payment-element");

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    setLoading(true);

    stripe
      .confirmPayment({
        elements,
        confirmParams: {
          // Make sure to change this to your payment completion page
          return_url: "http://localhost:4000/events",
        },
        redirect: "if_required",
      })
      .then((result) => {
        if (result.error) {
          if (
            result.error.type === "card_error" ||
            result.error.type === "validation_error"
          ) {
            showMessage(result.error.message);
          } else {
            showMessage("An unexpected error occurred.");
          }

          setLoading(false);
        }
      });
  });
};

// ------- UI helpers -------

function showMessage(messageText) {
  const messageContainer = document.querySelector("#payment-message");

  messageContainer.classList.remove("hidden");
  messageContainer.textContent = messageText;

  setTimeout(function () {
    messageContainer.classList.add("hidden");
    messageText.textContent = "";
  }, 4000);
}

// Show a spinner on payment submission
function setLoading(isLoading) {
  if (isLoading) {
    // Disable the button and show a spinner
    document.querySelector("#submit").disabled = true;
    document.querySelector("#spinner").classList.remove("hidden");
  } else {
    document.querySelector("#submit").disabled = false;
    document.querySelector("#spinner").classList.add("hidden");
  }
}
