/* License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/)
 *
 * Code based on the answer by the user Hashbrown dated 2020-Jan-27 at 5:53 on the page
 * https://stackoverflow.com/questions/49971575/chrome-fetch-api-cannot-load-file-how-to-workaround
 *
 * According stackoverflow, contributions at that date were licensed under CC BY-SA 4.0,
 * see https://stackoverflow.com/help/licensing
 *
 * Modified in 2024 by Lothar Ketterer
 */

// Reason for shadowing the Fetch API and replacing it by calls to XMLHttpRequest()
// is that the original fetch() fails with error messages such as:
//   'Fetch API cannot load webxdcfilerequest://localhost/DependencyLicenses.txt.
//    URL scheme "webxdcfilerequest" is not supported.'
//
// Of note, setting localContentCanAccessFileUrls to true in the WebEngineView settings
// in WebxdcPage.qml did not fix it.

window.fetch = (resource) => (
    new Promise(function(resolve, reject) {
        let request = new XMLHttpRequest();

        let fail = (error) => {reject(error)};
        ['error', 'abort'].forEach((event) => { request.addEventListener(event, fail); });

        let pull = (expected) => (new Promise((resolve, reject) => {
            if (
                request.responseType == expected ||
                (expected == 'text' && !request.responseType)
            )
                resolve(request.response);
            else
                reject(request.responseType);
        }));

        request.addEventListener('load', () => (resolve({
            arrayBuffer : () => (pull('arraybuffer')),
            blob        : () => (pull('blob')),
            text        : () => (pull('text')),
            json        : () => (pull('json'))
        })));
        request.open('GET', resource);
        request.send();
    })
);
