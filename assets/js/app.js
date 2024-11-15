// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { InitCheckout } from "./checkout";
import Sortable from "sortablejs";

let Hooks = {};
Hooks.InitCheckout = InitCheckout;

Hooks.Sortable = {
  mounted() {
    let batch = this.el.dataset.batch;
    new Sortable(this.el, {
      animation: 150,
      ghostClass: "bg-accent/50",
      dragClass: "bg-accent/20",
      fallbackOnBody: true,
      invertSwap: true,
      swapThreshold: 0.65,
      group: "shared",
      onEnd: (e) => {
        let params = {
          old: e.oldIndex,
          new: e.newIndex,
          to: e.to.dataset,
          ...e.item.dataset,
        };
        this.pushEventTo(this.el, "drop", params);
      },
    });
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// Allows to execute JS commands from the server
window.addEventListener("phx:js-exec", ({ detail }) => {
  document.querySelectorAll(detail.to).forEach((el) => {
    liveSocket.execJS(el, el.getAttribute(detail.attr));
  });
});

// Set dark/light mode
function applyColorMode(mode) {
  document.documentElement.classList.toggle("dark", mode === "dark");
}

window
  .matchMedia("(prefers-color-scheme: dark)")
  .addEventListener("change", (event) => {
    console.log("event");
    if (!("theme" in localStorage)) {
      applyColorMode(event.matches ? "dark" : "light");
    }
  });

applyColorMode(
  window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light",
);
