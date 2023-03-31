import http from "k6/http";
import { sleep, check, fail } from "k6";
import ws from "k6/ws";

const cookie = __ENV.COOKIE;

export default function() {
  const host = "localhost:4000";
  const origin = `http://${host}`;
  const wsProtocol = "ws";
  const options = {
    redirects: 0,
    cookies: {
      _tiki_key: cookie,
    },
  };

  let url = `http://${host}/events`;
  let res = http.get(url, options);

  url = `http://${host}/events/1/purchase`;
  res = http.get(url, options);

  check(res, {
    "purchase page status 200": (r) => r.status === 200,
  });

  checkLiveViewUpgrade(host, origin, wsProtocol, cookie, res, url);
}

// Connects the websocket to ensure the LV is upgraded.
//
// - parse the response HTML to find the LiveView websocket connection information (csrf token, topic etc)
// - build a `phx_join` message payload
// - issue a ws.connect()
//  - including several callback handlers
// - when a socket message was received, we assume the view was upgraded, and the websocket is closed.
function checkLiveViewUpgrade(
  host,
  testHost,
  wsProto,
  cookie,
  response,
  url,
  opts = {}
) {
  const debug = opts.debug || false;
  // The response header contains the websocket connection details
  const props = grabLVProps(response);
  const wsCsrfToken = props.wsCsrfToken;
  const phxSession = props.phxSession;
  const phxStatic = props.phxStatic;
  const topic = `lv:${props.phxId}`;
  const ws_url = `${wsProto}://${host}/live/websocket?vsn=2.0.0&_csrf_token=${wsCsrfToken}`;

  if (debug) console.log(`connecting ${ws_url}`);

  const joinMsg = JSON.stringify(
    encodeMsg(null, 0, topic, "phx_join", {
      url: url,
      params: {
        _csrf_token: wsCsrfToken,
        _mounts: 0,
      },
      session: phxSession,
      static: phxStatic,
    })
  );

  var response = ws.connect(
    ws_url,
    {
      headers: {
        Cookie: `_tiki_key=${cookie}`,
        Origin: testHost,
      },
    },
    function(socket) {
      socket.on("open", () => {
        socket.send(joinMsg);
        if (debug) console.log(`websocket open: phx_join topic: ${topic}`);
      }),
        socket.on("message", (message) => {
          checkMessage(message, `"status":"ok"`);
          socket.close();
        });
      socket.on("error", handleWsError);
      socket.on("close", () => {
        // should we issue a phx_leave here?
        if (debug) console.log("websocket disconnected");
      });
      socket.setTimeout(() => {
        console.log("10 seconds passed, closing the socket");
        socket.close();
        fail("websocket closed");
      }, 10000);
    }
  );

  checkStatus(response, 101);
}

function encodeMsg(id, seq, topic, event, msg) {
  return [`${id}`, `${seq}`, topic, event, msg];
}

function handleWsError(e) {
  if (e.error() != "websocket: close sent") {
    let msg = `An unexpected error occurred: ${e.error()}`;
    if (debug) console.log(msg);
    fail(msg);
  }
}

function grabLVProps(response) {
  let elem = response.html().find("meta[name='csrf-token']");
  let wsCsrfToken = elem.attr("content");

  if (!check(wsCsrfToken, { "found WS token ": (token) => !!token })) {
    fail("websocket csrf token not found");
  }

  elem = response.html().find("div[data-phx-main]");
  let phxSession = elem.data("phx-session");
  let phxStatic = elem.data("phx-static");
  let phxId = elem.attr("id");

  if (!check(phxSession, { "found phx-session": (str) => !!str })) {
    fail("session token not found");
  }

  if (!check(phxStatic, { "found phx-static": (str) => !!str })) {
    fail("static token not found");
  }

  return { wsCsrfToken, phxSession, phxStatic, phxId };
}

export function checkStatus(response, status, msg = "request failed") {
  if (
    !check(response, {
      "status OK": (res) => res.status.toString() === `${status}`,
    })
  ) {
    fail(`${msg} (Status: ${response.status.toString()}. Expected: ${status})`);
  }
}

export function checkMessage(message, regex, msg = "unexpected ws message") {
  if (!check(msg, { "ws msg OK": () => message.match(regex) })) {
    console.log(message);
    fail(`${msg} (Msg: ${message}. Expected: ${regex})`);
  }
}
