import QrScanner from "qr-scanner";

let Scanner = {
  mounted() {
    this.qrscanner = new QrScanner(this.el, (result) =>
      this.pushEvent("check_in", { ticket_id: result }),
    );

    this.el.addEventListener("start_scan", () => {
      this.qrscanner.start();
    });
  },
};

export default Scanner;
