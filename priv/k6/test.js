import Liveview from "./utilities/phoenix-liveview.js";
import { sleep, check, fail } from "k6";

// See https://k6.io/docs/using-k6/options/#using-options for documentation on k6 options
export const options = {
  vus: 500,
  duration: '60s',
  http_req_failed: ['rate<0.01'],
  http_req_duration: ['p(95)<200'],
};

const cookie = __ENV.COOKIE;

export default function () {
  // To set dynamic (e.g. environment-specific) configuration, pass it either as environment
  // variable when invoking k6 or by setting `:k6, env: [key: "value"]` in your `config.exs`,
  // and then access it from `__ENV`, e.g.: `const url = __ENV.url`

  let liveview = new Liveview("http://localhost:4000/events/1/purchase", "ws://localhost:4000/live/websocket?vsn=2.0.0", {
    headers: {
      Cookie: `_tiki_key=${cookie}`
    }
  });

  let res = liveview.connect(() => {
    liveview.send(
      "event",
      { type: "click", event: "inc", value: { "id": 3 }, cid: 1 },
      (_response) => {
        liveview.leave();
      }
    );
  }, {
    cookies: {
      _tiki_key: cookie,
    },
  });

  check(res, { "status is 101": (r) => r && r.status === 101 });

  sleep(1)
}
