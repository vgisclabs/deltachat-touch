//.pragma library
// this pragma makes it a singleton
// FIND OUT TODO: is mjs always singleton?

import { RawClient } from "client.mjs"

let _request_sender = (r) => console.log("request sender was not set, ignoring", r)

export function setSendRequest(send_handler) {
  _request_sender = send_handler
}

function sendRequest(request) {
  _request_sender(request)
}

class BaseTransport {
  constructor() {
    this._requests = new Map();
    this._requestId = 0;
  }
  _send(_message) {
    sendRequest(JSON.stringify(_message))
  }
  close() {
  }
  _onmessage(message) {
    if (!message.id)
      return;
    const response = message;
    if (!response.id)
      return;
    const handler = this._requests.get(response.id);
    if (!handler)
      return;
    if (response.error)
      handler.reject(response.error);
    else
      handler.resolve(response.result);
  }
  notification(method, params) {
    const request = {
      jsonrpc: "2.0",
      method,
      id: 0,
      params
    };
    this._send(request);
  }
  request(method, params) {
    const id = ++this._requestId;
    const my_request = {
      jsonrpc: "2.0",
      method,
      id,
      params
    };
    this._send(my_request);
    return new Promise((resolve, reject) => {
      this._requests.set(id, { resolve, reject });
    });
  }
};

const jsonrpc_transport_instance = new BaseTransport()

export function receiveResponse(response) {
  // console.log("response", response, JSON.parse(response))
  jsonrpc_transport_instance._onmessage(JSON.parse(response))
}

export const client = new RawClient(jsonrpc_transport_instance)
