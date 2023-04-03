let stripe;
let elements;

export const InitCheckout = {
    mounted() {
        stripe = Stripe("pk_test_51KWkyIER7ko6YTop95lS7iFgl8Y0BtV7a0NszFX2VnRCxEdferfKMuHFilAqYs0rK8ZZd9JrNgNlQU8RrXGbnN3c005S5fZ4Oh");
        const callback = intent => { this.pushEventTo(this.el, "payment-sucess", intent) };
        init(this.el, callback);
    }
}


const init = (form, callback) => {
    const clientSecret = form.dataset.secret;

    const appearance = { theme: 'stripe' };
    elements = stripe.elements({ appearance, clientSecret });

    const linkAuthenticationElement = elements.create("linkAuthentication");
    linkAuthenticationElement.mount("#link-authentication-element");

    linkAuthenticationElement.on('change', (event) => {
        emailAddress = event.value.email;
    });

    const paymentElementOptions = {
        layout: "tabs",
    };

    const paymentElement = elements.create("payment", paymentElementOptions);
    paymentElement.mount("#payment-element");

    form.addEventListener("submit", (e) => {
        e.preventDefault();
        setLoading(true);
    
        stripe.confirmPayment({
            elements,
            confirmParams: {
                // Make sure to change this to your payment completion page
                return_url: "http://localhost:4000/events",
                receipt_email: emailAddress,
            },
            redirect: "if_required"
        }).then((result) => {
            if (result.error) {
                if (result.error.type === "card_error" || result.error.type === "validation_error") {
                    showMessage(result.error.message);
                } else {
                    showMessage("An unexpected error occurred.");
                }
            
                setLoading(false);
            }
            callback(result.paymentIntent)
        })
    });
}

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
        document.querySelector("#button-text").classList.add("hidden");
    } else {
        document.querySelector("#submit").disabled = false;
        document.querySelector("#spinner").classList.add("hidden");
        document.querySelector("#button-text").classList.remove("hidden");
    }
}