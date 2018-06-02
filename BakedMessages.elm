module BakedMessages exposing
  ( kernel_info_request_msg
  , error_execute_request_msg
  , basic_execute_request_msg
  , fancy_execute_request_msg
  , stdout_execute_request_msg
  , resource_info_request_msg
  , sleep_request_msg
  )


import JMessages

kernel_info_request_msg = """
{
  "header": {
    "msg_type": "kernel_info_request",
    "username": "Popular Front",
    "session": "sessionyo",
    "date": "sup",
    "msg_id": ""
  },
  "parent_header": {},
  "content": {},
  "metadata": {}
}
"""

empty_execute_request_msg = """{"header":{"msg_type":  "execute_request", "msg_id": ""}, "parent_header": {}, "metadata":{}}"""

error_execute_request_msg = """
{
  "header": {
    "msg_type": "execute_request",
    "username": "Popular Front",
    "date": "k",
    "session": "37F4106072824F45A3D2CF209C44C479",
    "msg_id": ""
  },
  "parent_header": {},
  "content": {
    "code": "import IPython.displas as d; d.HTML('I\'m a <b>fancy</b> <i>kind</i> of message'",
    "silent": false,
    "store_history": true,
    "user_expressions": {},
    "allow_stdin": true,
    "stop_on_error": true
  },
  "metadata": {}
}
"""

fancy_execute_request_msg = """
{
  "header": {
    "msg_type": "execute_request",
    "username": "Popular Front",
    "date": "k",
    "session": "37F4106072824F45A3D2CF209C44C479",
    "msg_id": ""
  },
  "parent_header": {},
  "content": {
    "code": "import IPython.display as d; import time, base64; logo = base64.decodebytes(b'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');d.display(d.Image(logo));time.sleep(1); d.HTML('<b>fancy</b>')",
    "silent": false,
    "store_history": true,
    "user_expressions": {},
    "allow_stdin": true,
    "stop_on_error": true
  },
  "metadata": {}
}
"""

stdout_execute_request_msg = """
{
  "header": {
    "msg_type": "execute_request",
    "username": "Popular Front",
    "session": "sessionyo",
    "date": "",
    "msg_id": ""
  },
  "parent_header": {},
  "content": {
    "code": "print('hallo JupyterCon!')",
    "silent": false,
    "store_history": true,
    "user_expressions": {},
    "allow_stdin": true,
    "stop_on_error": true
  },
  "metadata": {}
}
"""



basic_execute_request_msg = """
{
  "header": {
    "msg_id": "",
    "username": "Popular Front",
    "session": "37F4106072824F45A3D2CF209C44C479",
    "msg_type": "execute_request",
    "version": "5.0"
  },
  "metadata": {},
  "content": {
    "code": "2+2",
    "silent": false,
    "store_history": true,
    "user_expressions": {},
    "allow_stdin": true,
    "stop_on_error": true
  },
  "buffers": [],
  "parent_header": {},
  "channel": "shell"

}
"""

-- Still kind of bonkers that there's no String.replace
sleep_request_msg = String.split "2+2" basic_execute_request_msg |> String.join "import time; time.sleep(10)"

resource_info_request_msg = """
{
  "header": {
    "msg_id": "",
    "username": "Popular Front",
    "session": "47F4106072824F45A3D2CF209C44C479",
    "msg_type": "resource_info_request",
    "version": "5.0"
  },
  "metadata": {},
  "content": {},
  "buffers": [],
  "parent_header": {},
  "channel": "shell"
}
"""

  --"channel": "control"
--basic_execute_request_msg_ : Jmsg
--basic_execute_request_msg_ =
--  {
--    {},
--    "metadata": {},
--    "content": {
--      "code": "2+2",
--      "silent": false,
--      "store_history": true,
--      "user_expressions": {},
--      "allow_stdin": true,
--      "stop_on_error": true
--    },
--    "buffers": [],
--    {
--      "msg_id": "",
--      "username": "Popular Front",
--      "session": "37F4106072824F45A3D2CF209C44C479",
--      "msg_type": "execute_request",
--      "version": "5.0"
--    },
--    "channel": "shell"
--  }
