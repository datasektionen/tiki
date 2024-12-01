const fs = require("fs");
const path = require("path");

export default function ({ matchComponents, theme }) {
  let iconsDir = path.join(__dirname, "../vendor/payment-logos/assets");
  let values = {};
  let folders = ["apm", "cards", "generic", "wallets"];
  folders.forEach((dir) => {
    fs.readdirSync(path.join(iconsDir, dir)).map((file) => {
      let name = path.basename(file, ".svg");
      values[name] = { name, fullPath: path.join(iconsDir, dir, file) };
    });
  });
  matchComponents(
    {
      paymentlogo: ({ name, fullPath }) => {
        let content = fs
          .readFileSync(fullPath)
          .toString()
          .replace(/\r?\n|\r/g, "")
          .replace(/#/g, "%23")
          .replace(/\(/g, "%28")
          .replace(/\)/g, "%29");

        return {
          [`--paymentlogo-${name}`]: `url('data:image/svg+xml,${content}')`,
          backgroundImage: `var(--paymentlogo-${name})`,
          backgroundSize: "contain",
          backgroundRepeat: "no-repeat",
          display: "inline-block",
          width: theme("spacing.8"),
          height: theme("spacing.5"),
        };
      },
    },
    { values },
  );
}
