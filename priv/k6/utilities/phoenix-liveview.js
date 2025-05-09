import Channel from "./phoenix-channel.js";
import http from "k6/http";
import { parseHTML } from "k6/html";
import { URL } from "https://jslib.k6.io/url/1.0.0/index.js";

export default class Liveview {
  constructor(url, websocketUrl, params = {}) {
    this.url = new URL(url);
    this.websocketUrl = new URL(websocketUrl);
    this.channel = null;
    this.params = params;
  }

  connect(callback, getParams = null, parseBody = this._parseBody) {
    let response = http.get(this.url.toString(), getParams);
    let { csrfToken, phxId, phxSession, phxStatic } = parseBody(
      response
    );

    this.websocketUrl.searchParams.append("vsn", "2.0.0");
    this.websocketUrl.searchParams.append("_csrf_token", csrfToken);
    let topic = `lv:${phxId}`;

    this.channel = new Channel(
      this.websocketUrl.toString(),
      topic,
      this.params,
      () => {}
    );

    return this.channel.join(
      {
        url: this.url.toString(),
        session: phxSession,
        static: phxStatic,
        params: {
          _csrf_token: csrfToken,
          _mounts: 0
        }
      },
      callback
    );
  }

  leave() {
    this.channel.leave();
  }

  setInterval(callback, interval) {
    return this.channel.setInterval(callback, interval);
  }

  setTimeout(callback, period) {
    return this.channel.setTimeout(callback, period);
  }

  send(event, payload, callback = () => {}) {
    this.channel.send(event, payload, callback);
  }

  _parseBody(response) {
    let elem = response.html().find("meta[name='csrf-token']")
    let csrfToken = elem.attr("content");

    elem = response.html().find("div[data-phx-main]");
    let phxSession = elem.data("phx-session");
    let phxStatic = elem.data("phx-static");
    let phxId = elem.attr("id");   
    
    return {
      csrfToken,
      elem,
      phxId,
      phxSession,
      phxStatic,
    };

    
  }
}
