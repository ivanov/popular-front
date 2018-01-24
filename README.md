# Jovyan Popular Front

Prototyping UI and UX ideas for Jupyter notebooks (in Elm).

## Installation (user)

(TODO: this isn't a supported  option at the moment)

## Installation (for Popular Front development)

On any platform, get `npm` and run:

```
npm install -g elm
```

(Alternatively, you can [get a binary installer for Mac and
Windows](https://guide.elm-lang.org/install.html)).

Install the elm package dependencies.
```
elm-package install
```


## Usage
Start up a `elm-reactor`, which will compile and serve the popular front, and
recompile it if you make any changes to the elm code.

```
elm-reactor
```

Navigate to [http://localhost:8000/front.elm](http://localhost:8000/front.elm) -
where you should see the UI with a red bar at the top that says "Not connected".

Now start a jupyter notebook server, making sure to pass the `allow_origin`
parameter which specifies the URL the elm-reactor is serving to, like so:

```
jupyter notebook --NotebookApp.allow_origin="http://localhost:8000" --NotebookApp.token='' --NotebookApp.password='' --NotebookApp.disable_check_xsrf=True
```


## Common Failure modes
Message in browser javascript console when we can't connect:

```
Cross-Origin Request Blocked: The Same Origin Policy disallows reading the remote resource at http://localhost:8888/api/sessions?token=720230a0a6f60646c17c51f673405e86a9cbedab08eba10d. (Reason: CORS header ‘Access-Control-Allow-Origin’ missing).
```
or

```
GET http://localhost:8888/api/kernels/31004fe1-31cb-4529-9ff2-214c4abfc5fa/channels [HTTP/1.1 403 Forbidden 6ms]
Firefox can’t establish a connection to the server at ws://localhost:8888/api/kernels/31004fe1-31cb-4529-9ff2-214c4abfc5fa/channels.
```

In the notebook server log:
```
[W 10:14:08.137 NotebookApp] Blocking Cross Origin API request for
/api/sessions.  Origin: http://localhost:8000, Host: localhost:8888]
```

or 

```
[W 12:16:22.890 NotebookApp] Blocking Cross Origin WebSocket Attempt.  Origin: http://localhost:8000, Host: localhost:8888
[W 12:16:22.891 NotebookApp] 403 GET /api/kernels/31004fe1-31cb-4529-9ff2-214c4abfc5fa/channels (::1) 4.60ms referer=None
```

That's because we didn't start with allow origin. (`jupyter notebook
--NotebookApp.allow_origin="http://localhost:8000"` or wherever the jovyan
popular front is being served from).




## TODO list
- [x] figure out how to get websocket connection from the jupyter sessions
- [x] enable cross-origin websockets
    [W 20:30:49.695 NotebookApp] Blocking Cross Origin API request for /api/kernels/08f00356-1bbc-45ef-99ca-8163462a5ee7.  Origin: http://localhost:8000, Host: localhost:8888
    [W 20:30:49.697 NotebookApp] 404 GET /api/kernels/08f00356-1bbc-45ef-99ca-8163462a5ee7 (::1) 2.02ms referer=None)]]
  nb --NotebookApp.allow_origin="http://localhost:8000" # start notebook server this way
    - [ ] idea: make a websocket backchannel...
- [x] let's send a kernel_info_request on initial load...
- [x] toggle raw and rendered message mode....

- [x] let's get the sessions object (across origins) and go from there...
    http://localhost:8888/api/sessions
- [x] make websocket port part of model
- [x] make server url + port part of model
- [x] specify server url + port in UI (assumes localhost)
- [ ] fetch api/sessions on server url change (to see if connected)
    - [ ] timeout the fetching of api/sessions / deal with errors
- [x] specify whole connection URL in UI (via dropdown)
- [ ] make a drop down for mime-types in display/execute_reply messages
- [x] prettify message rendering
- [ ] - (minor)  - leading 0 formatting  for single digit time values

- [x] status - connected or not...
- [ ] filter out status messages to their own queue (gets visually busy otherwise...)
    - like mailbox smart filter
- [ ] "view raw" version of a message, once we get rendering done properly
- [x] specify the right channel for outgoing messages
    - [I 21:27:55.821 NotebookApp] Adapting to protocol v5.1 for kernel
      57cd23b2-e6b1-4458-93ed-2c513b0442ca [W 21:28:19.603 NotebookApp] No
      channel specified, assuming shell
- [ ] use wss? (secure websockets)
- [x] hook up arrow keys for changing message in focus
- [ ] make simpler messages by type... (StatusMessage ....)
    - would make it easier to case switch on message types in rendering
- [ ] link messages (threaded view)
- [ ] remove message from the front, too (via one of the sliders)
- [x] - add notebook path to list, instead of kernel string
- [x] clear messages button...
- [ ] display messages (mime-type drop down / attachment analogy
- [ ] better formatting for UI messages (pretty)

- [x] save outgoing messages... inside our list, probably...
  -- or in a seperate ("outgoing" queue) - so we don't have to encode them...

- [ ] make a port for JSON.stringify and call it will null, 2...
    - nope, this will have to wait for later, elm-reactor doesn't support ports

- [ ] after talk: clean up dependency on indexes for active message. too britle.
- [ ] make the outgoing execute request valid, so it parses back into a Jmsg
- [ ] clearing messages should reset focus to Nothing
- [ ] <- and -> arrows for incoming  and outgoing messages
- [ ] highlight current message
- [ ] highlight parent message
- [ ] highlight by message type
- [x] arrow keys to go through messages
- [ ] timestamp on subject...
- [x] clear messages when switching kernels / notebooks
- [x] restart a kernel from the UI (for making changes)
- [x] rendering mime bundles on the page
      - using innerHtml property in virtualdom?
- [x] fix off by one error in msg + rawMsg stuff.
- [p] use oneOf decoders for splitting message types
- [ ] proper pre-flight xsrf token request handling
- [ ] random seed input box (for reproducible testing)
- [ ] Ctrl-C should send interrupt, not clear
- [ ] send message when the cross origin stuff is not set up
- [ ] and when the token is wrong (403)
- [ ] support comm messages
- [ ] message order editor (vi keys)
      - delete with 'd' or 'x'
      - paste with 'p'
      - copy with 'y'
      - undo with 'u' (ideally would be multi-level)
- [ ] scrolling for messages inside container


### upstream cleanup
- [ ] why do we have the same thing in msg_type in the header and in the raw thing...
- [ ] ANSI escape codes in execute_reply when there are error messages




### miscellaneous notes
-- sample message
```
{"header":{"msg_id":"9616C6F009194735873B804684D3EDD2","username":"username","session":"CC87D0D1ED2B455E8083A8AF90A7400A","msg_type":"kernel_info_request","version":"5.0"},"metadata":{},"content":{},"buffers":[],"parent_header":{},"channel":"shell"}
```


messages to render - show off
execution
stream (stdout) (content name)
result
