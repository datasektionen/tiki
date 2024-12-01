const allowedKeys = new Set(["ArrowUp", "ArrowDown", "Enter"]);

export const SearchCombobox = {
  mounted() {
    let input = this.el;
    document.addEventListener("keydown", (event) => {
      if (!allowedKeys.has(event.key)) {
        return;
      }

      const focused = document.querySelector(":focus");

      if (!focused || !input.contains(focused)) {
        return;
      }

      event.preventDefault();
      let elements = this.el.querySelectorAll("input, li");
      let index = Array.from(elements).indexOf(focused);
      let count = elements.length;

      if (event.key === "Enter" && index > 0) {
        let data = elements[index].dataset;
        this.pushEventTo(this.el, "chosen", data);
      }

      if (event.key === "ArrowUp") {
        elements[index > 0 ? index - 1 : tabElementsCount].focus();
      }

      if (event.key === "ArrowDown") {
        elements[index < count ? index + 1 : 0].focus();
      }
    });
  },
};
