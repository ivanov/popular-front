import Html exposing (..)
import Html.Attributes as Attr exposing (..)
import Html.Events exposing (..)
import RemoteData exposing (RemoteData(..))
import WebSocket
import Http
import Task
import Time exposing (Time, now)

-- import JupyterMessages exposing (..)

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

type alias Session = String

-- MODEL

type alias Model =
  { input : String
  , messages : List String
  , session : RemoteData Http.Error Session
  , index : Maybe Int
  , connectionString : String
  }


init : (Model, Cmd Msg)
init =
  (Model "" ["hey", "how", "are", " you"] NotAsked Nothing "349fa50a-fd05-4ae6-adf5-cf482f63bfa4" , Task.perform identity (Task.succeed Connect))


-- UPDATE

type Msg
  = Input String
  | Send
  | Connect
  | NewMessage String
  | NewTimeMessage Time String
  | UpdateIndex String
  | GetTimeAndThen (Time -> Msg)


newMessage str = GetTimeAndThen (\time -> NewTimeMessage time str)


ws_url : Model -> String
--ws_url = "ws://localhost:8888/api/kernels/d341ae22-0258-482b-831a-fa0a0370ffba"
--ws_url = "http://localhost:8888/api/kernels/d341ae22-0258-482b-831a-fa0a0370ffba/channels?session_id=6CCE28259904425785B76A7D45D9EB26"
--ws_url = "ws://localhost:8080/echo"
--ws_url = "ws://localhost:8888/api/kernels/08f00356-1bbc-45ef-99ca-8163462a5ee7"
--ws_url = "ws://localhost:8888/api/kernels/57cd23b2-e6b1-4458-93ed-2c513b0442ca"
-- ws_url = "ws://localhost:8888/api/kernels/57cd23b2-e6b1-4458-93ed-2c513b0442ca/channels?session_id=6A5BB323BD6F41A3B95860E4441716C1"
--ws_url = "ws://localhost:8888/api/kernels/31004fe1-31cb-4529-9ff2-214c4abfc5fa/channels?session_id=132CABB1A5B749FCACC7E3FAC30E42FC"
-- 349fa50a-fd05-4ae6-adf5-cf482f63bfa4
ws_url model = "ws://localhost:8888/api/kernels/" ++ model.connectionString ++ "/channels"

kernel_info_request_msg = """{"header":{"msg_type":  "kernel_info_request", "msg_id":""}, "parent_header": {}, "metadata":{}}"""

update : Msg -> Model -> (Model, Cmd Msg)
--update msg {input, messages, sessions} =
update msg model =
  case msg of
    Input newInput ->
      { model
      | input = newInput
      } ! [ Cmd.none ]

    Connect ->
      { model
      | input = ""
      , session = Loading
      } ! [ WebSocket.send (ws_url model) kernel_info_request_msg ]

    Send ->
      { model
      | input = ""
      , session = Loading
      } ! [ WebSocket.send (ws_url model) model.input ]

    NewMessage str ->
    { model
    --| messages = str :: model.messages
    | messages = model.messages ++ [str]
    , session = Success "OK"
    } ! [ Cmd.none ]

    GetTimeAndThen successHandler ->
    ( model, (Task.perform successHandler now) )

    NewTimeMessage time str ->
    { model
    --| messages = str :: model.messages
    | messages = model.messages ++ [str ++ (formatTime time)]
    } ! [ Cmd.none ]
    UpdateIndex str ->
    { model
    | index = Just <| Result.withDefault 0 <| String.toInt str
    } ! [ Cmd.none ]

-- Timezone offset (relative to UTC)
tz = -7

formatTime : Time -> String
formatTime t
  = String.concat <| List.intersperse ":" <| List.map toString
      [ floor (Time.inHours t)  % 24 + tz
      , floor (Time.inMinutes t)  % 60
      , floor (Time.inSeconds t)  % 60
      ]

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  WebSocket.listen (ws_url model) NewMessage


-- VIEW
(=>) = (,)

view : Model -> Html Msg
view model =
  div
    [ style
      [ "display" => "flex"
      , "margin" => "0"
      , "flex-direction" => "column"
      , "min-height" =>  "100vh"
      ]
    ]
    [ viewStatus model
    , div [] <| viewValidMessages model
    , input [onInput Input] []
    , button [onClick Send] [text "Send"]
    , button [onClick <| newMessage  "--- mark --- "] [text "add marker"]
        --<| "--- mark --- " ++ (toString <| Task.perform <| \a ->  Time.now )] [text "Add Marker"]
    , div [style ["flex" => "1"]] []
    , viewTimeSlider model
    , viewTimeSlider model
    , viewTimeSlider model
    ]

viewStatus : Model -> Html Msg
viewStatus model =
  let
    (color, message) = case model.session of
        NotAsked -> ("red", "Not connected")
        Loading -> ("yellow", "Not connected")
        Success _ -> ("green", "Connected")
        Failure x -> ("red", "Failed to connect")
  in
    div [style ["background-color" => color]] [text message]



viewMessage : String -> Html msg
viewMessage msg =
  div [] [ text msg ]

viewValidMessages : Model -> List (Html msg)
viewValidMessages model =
  let msgs = case model.index of
    Nothing -> model.messages
    Just i -> List.take i model.messages
  in
    List.map viewMessage msgs



viewTimeSlider : Model -> Html Msg
viewTimeSlider model =
  let
    len = List.length model.messages
  in
  footer []
  [ input
      [ type_ "range"
      , Attr.min "0"
      , Attr.max <| toString len
      , value <| toString <| Maybe.withDefault len model.index
      , onInput UpdateIndex
      , style ["width" => "96%"]
      ] [text "hallo"]
  ]
