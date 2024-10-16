/*
 * Copyright (C) 2022 Delta Chat contributors.
 * Copyright (C) 2024 Lothar Ketterer
 *
 * This file is part of the app "DeltaTouch".
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * deltatouch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * This file was originally taken in June 2024 from
 * https://github.com/deltachat/deltachat-android/blob/e0f83cdc54c833981d4c5967a09c42c1c67b9659/res/raw/webxdc.js
 * licensed under GLPv3 by Delta Chat contributors, and modified
 * by Lothar Ketterer.
 */

cppside = parent.cppside
fetch = parent.fetch

// ===================================================================
// =================== For <input> element override ==================
// ===================================================================

currentInput = null

window.__setInput = function(newtime) {
    currentInput.value = newtime
}

parent.__setInput = window.__setInput

document.addEventListener('mousedown', function(evt) {
    var input = null
    if (evt.target.tagName === "INPUT") {
        currentInput = evt.target

        if (currentInput !== null && evt.target.type === "time") {
            evt.preventDefault()
            cppside.getDateTimeInput(currentInput.value, false, true)
        }

        // For type="date", the default popup can be used. It's not
        // optimal, but the current custom solutions aren't, either.
//        if (currentInput !== null && evt.target.type === "date") {
//            evt.preventDefault()
//            cppside.getDateTimeInput(currentInput.value, true, false)
//        }

        if (currentInput !== null && evt.target.type === "datetime-local") {
            evt.preventDefault()
            cppside.getDateTimeInput(currentInput.value, true, true)
        }
    }
})

// Loads the css that suppresses the icon on <input type="time"> and
// <input type="datetime-local"> elements. The app provides its own
// popup to set the (date)time as the default popup by Qt WebengineView
// does not react to touch input.
let temphead  = document.getElementsByTagName("HEAD")[0];
let templink  = document.createElement('link');
templink.rel  = 'stylesheet';
templink.type = 'text/css';
templink.href = '2346123058123r12835asd2834.css';
temphead.appendChild(templink);

// =======================================================================
// =================== END For <input> element override ==================
// =======================================================================


window.webxdc = (() => {
  let setUpdateListenerPromise = null
  var update_listener = () => {};
  var last_serial = 0;

  window.__webxdcUpdate = () => {
    cppside.getStatusUpdates(last_serial, function(_updates) {
        var updates = JSON.parse(_updates);
        updates.forEach((update) => {
            update_listener(update);
            last_serial = update.serial;
        });
        if (setUpdateListenerPromise) {
          setUpdateListenerPromise()
          setUpdateListenerPromise = null
        }
    })
  };

  parent.__webxdcUpdate = window.__webxdcUpdate;


  return {
    selfAddr: cppside.selfAddr,

    selfName: cppside.selfName,

    setUpdateListener: (cb, serial) => {
        last_serial = typeof serial === "undefined" ? 0 : parseInt(serial);
        update_listener = cb
        var promise = new Promise((res, _rej) => {
          setUpdateListenerPromise = res
        })
        window.__webxdcUpdate();
        return promise
    },

    // deprecated 2022-02-20 all updates are returned through the callback set by setUpdateListener
    getAllUpdates: () => {
      console.error("deprecated 2022-02-20 all updates are returned through the callback set by setUpdateListener")
      return Promise.resolve([]);
    },

    sendUpdate: (payload, descr) => {
      cppside.sendStatusUpdate(JSON.stringify(payload), descr);
    },

    sendToChat: async (message) => {
      const data = {};
      if (!message.file && !message.text) {
        return Promise.reject("sendToChat() error: file or text missing");
      }

      const blobToBase64 = (file) => {
        const dataStart = ";base64,";
        return new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.readAsDataURL(file);
          reader.onload = () => {
            let data = reader.result;
            resolve(data.slice(data.indexOf(dataStart) + dataStart.length));
          };
          reader.onerror = () => reject(reader.error);
        });
      };
      if (message.text) {
        data.text = message.text;
      }

      if (message.file) {
        let base64content;
        if (!message.file.name) {
          return Promise.reject("sendToChat() error: file name missing");
        }
        if (
          Object.keys(message.file).filter((key) =>
            ["blob", "base64", "plainText"].includes(key)
          ).length > 1
        ) {
          return Promise.reject("sendToChat() error: only one of blob, base64 or plainText allowed");
        }

        if (message.file.blob instanceof Blob) {
          base64content = await blobToBase64(message.file.blob);
        } else if (typeof message.file.base64 === "string") {
          base64content = message.file.base64;
        } else if (typeof message.file.plainText === "string") {
          base64content = await blobToBase64(new Blob([message.file.plainText]));
        } else {
          return Promise.reject("sendToChat() error: none of blob, base64 or plainText set correctly");
        }
        data.base64 = base64content;
        data.name = message.file.name;
      }

      cppside.sendToChat(JSON.stringify(data), function(errorMsg) {
          if (errorMsg) {
            return Promise.reject(errorMsg);
          }
      });
    },

    importFiles: (filters) => {
        var element = document.createElement("input");
        element.type = "file";
        element.accept = [
            ...(filters.extensions || []),
            ...(filters.mimeTypes || []),
        ].join(",");
        element.multiple = filters.multiple || false;
        const promise = new Promise((resolve, _reject) => {
            element.onchange = (_ev) => {
                console.log("element.files", element.files);
                const files = Array.from(element.files || []);
                document.body.removeChild(element);
                resolve(files);
            };
        });
        element.style.display = "none";
        document.body.appendChild(element);
        element.click();
        console.log(element);
        return promise;
    },
  };
})();
