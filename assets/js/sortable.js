import Sortable from "sortablejs";

export const InitSorting = {
  mounted() {
    new Sortable(this.el, {
      animation: 150,
      ghostClass: "bg-bareground",
      dragClass: "shadow-2xl",
      onEnd: (e) => {
        let params = { from: e.oldIndex, to: e.newIndex };
        this.pushEvent("update-sort-order", params);
      },
    });
  },
};
