import Html exposing (..)
import Html.Attributes as Attr exposing (..)
import Html.Events exposing (..)
import RemoteData exposing (RemoteData(..))
import WebSocket
import Http
import Task
import Time exposing (Time, now)
import Json.Decode  exposing (decodeString)

-- import JupyterMessages exposing (..)
import JMessages exposing (..)

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

type alias Session = String
type RawOrRendered = Raw | Rendered

-- MODEL

type alias Model =
  { input : String
  , messages : List String
  , msgs : List Jmsg
  , session : RemoteData Http.Error Session
  , index : Maybe Int
  , connectionString : String
  , raw : RawOrRendered
  , focused : Maybe Int
  }


init : (Model, Cmd Msg)
init =
  (Model "" [] [] NotAsked Nothing "a09b920b-652f-4bae-8958-c3d182b9a5af" Rendered Nothing, Cmd.none )
  --Task.perform identity (Task.succeed Connect))



-- UPDATE

type Msg
  = Input String
  | Send
  | Connect
  | Ping
  | NewMessage String
  | NewTimeMessage Time String
  | UpdateIndex String
  | GetTimeAndThen (Time -> Msg)
  | ToggleRendered
  | Focus Int


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
empty_execute_request_msg = """{"header":{"msg_type":  "execute_request", "msg_id":""}, "parent_header": {}, "metadata":{}}"""

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

    Ping ->
      { model
      | input = ""
      , session = Loading
      } ! [ WebSocket.send (ws_url model) empty_execute_request_msg ]

    Send ->
      { model
      | input = ""
      , session = Loading
      } ! [ WebSocket.send (ws_url model) model.input ]

    NewMessage str ->
    let
      latest = case decodeString decodeJmsg str of
        Ok jmsg -> [(Debug.log "IT WORKS" jmsg)]
        Err msg -> let error = (Debug.log "Nope" msg)
                  in []
    in
      { model
      --| messages = str :: model.messages
      | messages = model.messages ++ [str]
      , msgs = model.msgs ++ latest
      , session = Success "OK"
      --, last_status = status
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
    ToggleRendered ->
    { model
    | raw  = case model.raw of
        Raw -> Rendered
        Rendered -> Raw
    } ! [ Cmd.none ]
    Focus i ->
    { model
    | focused = Just i
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
    , div[] [toggleRenderedStatus model, kernelInfoButton, pingButton]
    , div [] <| viewValidMessages model, viewFocused model
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



viewMessage : Int -> Jmsg -> Html Msg
viewMessage i msg =
  div [onClick (Focus i)] [ text <| msg.msg_type ++ ": " ++ msg.content.execution_state ]

viewRawMessage : Int -> String -> Html Msg
viewRawMessage i msg =
  div [onClick (Focus i)] [ text msg , hr [] [] ]


viewValidMessages : Model -> List (Html Msg)
viewValidMessages model =
   case model.raw of
      Raw ->
        let msgs = case model.index of
          Nothing -> model.messages
          Just i -> List.take i model.messages
        in
          List.indexedMap viewRawMessage msgs

      Rendered ->
        let msgs =  case model.index of
          Nothing -> model.msgs
          Just i -> List.take i model.msgs
        in
          List.indexedMap viewMessage msgs



viewTimeSlider : Model -> Html Msg
viewTimeSlider model =
  let
    len = case model.raw of
      Raw -> List.length model.messages
      Rendered -> List.length model.msgs
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

toggleRenderedStatus : Model -> Html Msg
toggleRenderedStatus model =
  let nextToggleValue = case model.raw of
    Raw -> "Rendered"
    Rendered -> "Raw"
  in
    button [onClick ToggleRendered] [text nextToggleValue]

kernelInfoButton : Html Msg
kernelInfoButton =
    button [onClick Connect] [text "kernel info"]

pingButton =
    button [onClick Ping] [text "Ping"]

viewFocused model =
  case model.focused of
    Just i ->
    let
      msg = if i > 0 then List.head <| List.drop (i-1) model.msgs else List.head model.msgs

    in
    case msg of
      Nothing -> div [] []
      Just msg ->
        -- TODO: put flexbox styling here
        div [] [text <| msg.msg_type ++ ": " ++ msg.content.execution_state ]
    Nothing -> div [] []
