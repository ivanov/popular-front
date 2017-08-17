# Jovyan Popular Front

- [ ] figure out how to get websocket connection from the jupyter sessions 
- [ ] enable cross-origin websockets
    [W 20:30:49.695 NotebookApp] Blocking Cross Origin API request for /api/kernels/08f00356-1bbc-45ef-99ca-8163462a5ee7.  Origin: http://localhost:8000, Host: localhost:8888
    [W 20:30:49.697 NotebookApp] 404 GET /api/kernels/08f00356-1bbc-45ef-99ca-8163462a5ee7 (::1) 2.02ms referer=None)]]
  nb --NotebookApp.allow_origin="http://localhost:8000" # start notebook server this way
    - [ ] idea: make a websocket backchannel...

- [ ] let's get the sessions object (across origins) and go from there...
    http://localhost:8888/api/sessions
- [ ] make websocket port part of model
- [ ] make a drop down for mime-types in display/execute_reply messages
- [ ] - (minor)  - leading 0 formatting  for single digit time values

- [x] status - connected or not...
- [ ] filter out status messages to their own queue (gets busy otherwise...)
  "view raw"



    - [I 21:27:55.821 NotebookApp] Adapting to protocol v5.1 for kernel 57cd23b2-e6b1-4458-93ed-2c513b0442ca [W 21:28:19.603 NotebookApp] No channel specified, assuming shell:
      {'header': 'sup'}}]]


-- sample message

{"header":{"msg_id":"9616C6F009194735873B804684D3EDD2","username":"username","session":"CC87D0D1ED2B455E8083A8AF90A7400A","msg_type":"kernel_info_request","version":"5.0"},"metadata":{},"content":{},"buffers":[],"parent_header":{},"channel":"shell"}

i

--- set of responses:
{"header": {"username": "pi", "msg_type": "status", "msg_id": "7fd3c98c-14c4f5ee4c55d07c55cfe40b", "version": "5.2", "session": "e12a7593-df88b7de88b1519e64b353bf", "date": "2017-08-03T04:35:37.953041Z"}, "msg_id": "7fd3c98c-14c4f5ee4c55d07c55cfe40b", "msg_type": "status", "parent_header": {"username": "username", "version": "5.0", "msg_type": "execute_request", "msg_id": "5391C9D4014D497A80A9F12622D9F9DD", "session": "CC87D0D1ED2B455E8083A8AF90A7400A", "date": "2017-08-03T04:35:37.943153Z"}, "metadata": {}, "content": {"execution_state": "idle"}, "buffers": [], "channel": "iopub"}
{"header": {"username": "pi", "msg_type": "execute_result", "msg_id": "c0593d54-85455e6a5b131350cd62c498", "version": "5.2", "session": "e12a7593-df88b7de88b1519e64b353bf", "date": "2017-08-03T04:35:37.948360Z"}, "msg_id": "c0593d54-85455e6a5b131350cd62c498", "msg_type": "execute_result", "parent_header": {"username": "username", "version": "5.0", "msg_type": "execute_request", "msg_id": "5391C9D4014D497A80A9F12622D9F9DD", "session": "CC87D0D1ED2B455E8083A8AF90A7400A", "date": "2017-08-03T04:35:37.943153Z"}, "metadata": {}, "content": {"execution_count": 5, "data": {"text/plain": "11"}, "metadata": {}}, "buffers": [], "channel": "iopub"}
{"header": {"username": "pi", "msg_type": "execute_input", "msg_id": "225fcd40-0a1cc1ffd7488ec76c938418", "version": "5.2", "session": "e12a7593-df88b7de88b1519e64b353bf", "date": "2017-08-03T04:35:37.946030Z"}, "msg_id": "225fcd40-0a1cc1ffd7488ec76c938418", "msg_type": "execute_input", "parent_header": {"username": "username", "version": "5.0", "msg_type": "execute_request", "msg_id": "5391C9D4014D497A80A9F12622D9F9DD", "session": "CC87D0D1ED2B455E8083A8AF90A7400A", "date": "2017-08-03T04:35:37.943153Z"}, "metadata": {}, "content": {"execution_count": 5, "code": "11"}, "buffers": [], "channel": "iopub"}
{"header": {"username": "pi", "msg_type": "status", "msg_id": "e4e8f5ca-d8dced3f56f081965c15176e", "version": "5.2", "session": "e12a7593-df88b7de88b1519e64b353bf", "date": "2017-08-03T04:35:37.945050Z"}, "msg_id": "e4e8f5ca-d8dced3f56f081965c15176e", "msg_type": "status", "parent_header": {"username": "username", "version": "5.0", "msg_type": "execute_request", "msg_id": "5391C9D4014D497A80A9F12622D9F9DD", "session": "CC87D0D1ED2B455E8083A8AF90A7400A", "date": "2017-08-03T04:35:37.943153Z"}, "metadata": {}, "content": {"execution_state": "busy"}, "buffers": [], "channel": "iopub"}


use JSON-to-Elm to get some elm code out of this...

https://eeue56.github.io/json-to-elm/


why do we have the same thing in msg_type in the header and in the raw thing...


message in console when we can't connect...

          GET 
http://localhost:8888/api/kernels/31004fe1-31cb-4529-9ff2-214c4abfc5fa/channels [HTTP/1.1 403 Forbidden 6ms]
Firefox can’t establish a connection to the server at ws://localhost:8888/api/kernels/31004fe1-31cb-4529-9ff2-214c4abfc5fa/channels.  

that's because we didn't start with allow origin


[W 12:16:22.889 NotebookApp] No session ID specified
[I 12:16:22.890 NotebookApp] Adapting to protocol v5.1 for kernel 31004fe1-31cb-4529-9ff2-214c4abfc5fa
[W 12:16:22.890 NotebookApp] Blocking Cross Origin WebSocket Attempt.  Origin: http://localhost:8000, Host: localhost:8888
[W 12:16:22.891 NotebookApp] 403 GET /api/kernels/31004fe1-31cb-4529-9ff2-214c4abfc5fa/channels (::1) 4.60ms referer=None


wss (secure websockets


let's send a kernel_info_request on initial load...

[x] toggle raw and rendered message mode....

[ ] make simpler messages by type... (StatusMessage ....)
  - would make it easier to case switch on message types in rednering
[ ] link messages (threaded view)




