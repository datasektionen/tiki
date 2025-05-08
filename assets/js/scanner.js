import QrScanner from "qr-scanner";

let Scanner = {
  mounted() {
    this.scanned = new Set();

    this.qrscanner = new QrScanner(
      this.el,
      (result) => {
        id = result.data;
        if (this.scanned.has(id)) {
          return;
        }

        this.scanned.add(id);
        this.pushEvent("check_in", { ticket_id: id, check_out: false });
      },
      { highlightScanRegion: true },
    );
    this.qrscanner.setInversionMode("both");

    this.el.addEventListener("start_scan", () => {
      this.qrscanner.start();
    });
  },

  destroyed() {
    this.qrscanner.destroy();
    this.qrscanner = null;
  },
};

export default Scanner;
