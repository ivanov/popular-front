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
    "username": "yo",
    "session": "sessionyo",
    "date": "sup",
    "msg_id": "f7793152-20a1e0729ce836887c79c611"
  },
  "parent_header": {},
  "content": {},
  "metadata": {}
}
"""

empty_execute_request_msg = """{"header":{"msg_type":  "execute_request", "msg_id":""}, "parent_header": {}, "metadata":{}}"""

error_execute_request_msg = """
{
  "header": {
    "msg_type": "execute_request",
    "msg_id": "2282972d-858548e9788469565e4d1984"
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
    "msg_id": "c81b7217-e75dbf6e838637710e829864"
  },
  "parent_header": {},
  "content": {
    "code": "import IPython.display as d; import time; d.display(d.Image('thumb/exitingvim-big.png'));time.sleep(1); d.HTML('<b>fancy</b>')",
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
    "username": "yo",
    "session": "sessionyo",
    "date": "",
    "msg_id": "7d2c0b07-56bbeb2574a05672fbafe450"
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
    "msg_id": "D349AA77DB1642E88EC2E1450B3E16C1",
    "username": "username",
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
    "msg_id": "E349BA77DB1642E88EC2E1450B3E16C1",
    "username": "something",
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
--      "msg_id": "D349AA77DB1642E88EC2E1450B3E16C1",
--      "username": "username",
--      "session": "37F4106072824F45A3D2CF209C44C479",
--      "msg_type": "execute_request",
--      "version": "5.0"
--    },
--    "channel": "shell"
--  }
