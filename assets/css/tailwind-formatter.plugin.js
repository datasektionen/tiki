// A super hacky way to get the tailwind formatter to work with our own custom
// classes.

const fs = require("fs");
const path = require("path");
const cssPath = path.join(__dirname, "app.css");
const buildPath = path.join(__dirname, "..", "..", "_build");

export default function ({}) {
  let css = fs.readFileSync(cssPath).toString();
  let re = new RegExp("--(.+): ", "gm");

  let matches = [...css.matchAll(re)].map((match) => match[1]);
  matches = new Set(matches);

  fs.writeFileSync(
    path.resolve(buildPath, "classes.txt"),
    Array.from(matches).join("\n"),
  );
}
