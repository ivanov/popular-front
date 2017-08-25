import Html exposing (..)
import Html.Attributes as Attr exposing (..)
import Html.Events exposing (..)
import RemoteData exposing (RemoteData(..))
import WebSocket
import Http
import Task
import Time exposing (Time, now)
import Date
import Json.Decode  exposing (decodeString)
import Json.Encode  exposing (encode)

import JMessages exposing (..)
import JSessions exposing (..)
import BakedMessages exposing (..)

import Keyboard
import Char exposing (toCode, fromCode)

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

type RawOrRendered = Raw | Rendered

-- MODEL

type alias Model =
  { input : String
  , messages : List String
  , msgs : List Jmsg
  , index : Maybe Int
  , connectionString : String
  , raw : RawOrRendered
  , focused : Maybe Int
  , server : String
  , sessions : RemoteData Http.Error (List Session)
  , activeSession : Maybe Session
  }


init : (Model, Cmd Msg)
init = (
  { input = ""
  , messages = []
  , msgs = []
  , index = Nothing
  , connectionString = ""
  , raw = Rendered
  , focused = Nothing
  , server = "localhost:8888"
  , sessions = NotAsked
  --, sessions = Success sampleSessions
  , activeSession = Nothing
  }
  --, Cmd.none)
  , Task.perform identity (Task.succeed ConnectAPI))



-- UPDATE

type Msg
  = Input String
  | Send
  | ConnectKernel
  | ConnectAPI
  | Ping String
  | NewMessage String
  | NewTimeMessage Time String
  | UpdateIndex String
  | GetTimeAndThen (Time -> Msg)
  | ToggleRendered
  | Focus Int
  | ChangeServer String
  | NewSessions (Result Http.Error (List Session))
  | SetActiveSession Session
  | ClearAllMessages
  | KeyMsgDown Keyboard.KeyCode


newMessage str = GetTimeAndThen (\time -> NewTimeMessage time str)


ws_url : Model -> String
--ws_url = "ws://localhost:8888/api/kernels/d341ae22-0258-482b-831a-fa0a0370ffba"
ws_url model
  =
  case model.activeSession of
  Nothing ->  Debug.log "~~~ uhoh" "http://shouldnothappen"
  Just s ->
    Debug.log "sending ws to..."
     "ws://" ++ model.server ++ "/api/kernels/" ++ s.kernel.id ++ "/channels"


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Input newInput ->
      { model
      | input = newInput
      } ! [ Cmd.none ]

    ConnectKernel ->
      { model
      | input = ""
      } ! [ WebSocket.send (ws_url model) kernel_info_request_msg ]

    Ping raw_msg ->
    let
      -- decoding from our sample raw messages doesn't work, let's fake it?
      x =  Debug.log "oops..."  (raw_msg == basic_execute_request_msg)
      new_msgs = case decodeString decodeJmsg raw_msg of
        Ok m -> [m]
        Err x -> Debug.log "oops..."  []
      --  if raw_msg == basic_execute_request_msg then
      --    [basic_execute_request_msg_] else []
    in
       { model
       | messages = model.messages ++ [raw_msg]
       , msgs = model.msgs ++ new_msgs
       } ! [ WebSocket.send (ws_url model) raw_msg ]

    Send ->
      { model
      | input = ""
      , sessions = Loading
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
    | focused = case Just i == model.focused  of
        True -> Nothing
        False -> Just i
    } ! [ Cmd.none ]

    ChangeServer s ->
    let
      new_model =
      { model
      | server = s
      , sessions = Loading
      }
    in
      new_model  ! [getSession new_model]

    ConnectAPI ->
      update (ChangeServer model.server) model


    NewSessions result ->
    let
      new_sessions = case result of
        Ok sessions -> Debug.log "hallo" Success sessions
        Err x ->  Debug.log "failure" Failure x
    in
      { model
      | sessions = new_sessions
      , activeSession = List.head <| Result.withDefault [] result
      } ! [Cmd.none]

    SetActiveSession s ->
    { model | activeSession = Just s} ! [Cmd.none]

    ClearAllMessages ->
    { model |  msgs = [], messages= [], focused=Nothing} ! [Cmd.none]

    KeyMsgDown code ->
      let focused = case fromCode code of
        'J' ->  case model.focused of
          Nothing -> Just 0
          Just i -> if (i+1 == List.length model.messages)  then Nothing else Just (i+1)
        'K' -> case model.focused of
          Nothing -> Just ((List.length model.messages) - 1 )
          --Just i -> Just (i-1)
          Just i -> if (i-1 == -1)  then Nothing else Just (i-1)
        _ ->  model.focused
      in
        { model | focused = focused } ! []

-- Timezone offset (relative to UTC)
tz = -7

formatTime : Time -> String
formatTime t
  = String.concat <| List.intersperse ":" <| List.map toString
      [ floor (Time.inHours t)  % 24 + tz
      , floor (Time.inMinutes t)  % 60
      , floor (Time.inSeconds t)  % 60
      ]

api_url : Model -> String
api_url model =
-- TODO: this is brittle - we should check if there's already a leading http://
-- in the url and not add it to the front in that case
-- TODO: support tokens and password
  Debug.log "URL is: " "http://" ++ model.server ++ "/api/sessions"

getSession : Model -> Cmd Msg
getSession model =
  let
    request = Debug.log "calling url" Http.get (api_url model) decodeSessions
  in
    Http.send NewSessions request

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  case model.activeSession of
    Nothing -> Sub.none
    _ -> Sub.batch
          [ WebSocket.listen (ws_url model) NewMessage
          , Keyboard.downs KeyMsgDown
          ]



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
    , div[] [toggleRenderedStatus model, kernelInfoButton, quickHTMLButton4, quickHTMLButton,
    quickHTMLButton3, quickHTMLButton2]
    , div [style ["display" => "flex", "flex-direction" => "row"]]
          [ table [style []] (viewValidMessages model)
          , viewFocused model]
    , input [onInput Input] []
    , button [onClick Send] [text "Send"]
    , button [onClick <| newMessage  "--- mark --- "] [text "add marker"]
    , button [onClick ClearAllMessages] [text "Clear all messages"]
        --<| "--- mark --- " ++ (toString <| Task.perform <| \a ->  Time.now )] [text "Add Marker"]
    , div [style ["flex" => "1"]] []
    , viewTimeSlider model
    , viewTimeSlider model
    , viewTimeSlider model
    ]

viewStatus : Model -> Html Msg
viewStatus model =
  let
    (color, message) = case model.sessions of
        NotAsked -> ("red", "Not connected")
        Loading -> ("yellow", "Loading...")
        Success _ -> ("green", "Connected")
        Failure x -> ("red", "Failed to connect")
  in
    div [style ["background-color" => color]] [viewServer model, text message]



viewMessage : Model -> Int -> Jmsg -> Html Msg
viewMessage model i msg =
  let
    s = case model.focused of
      Just j -> if i == j then ["background-color" => "orange"] else []
      Nothing -> []
    subj = text <| getSubject msg
    content  = case model.focused of
      Just j -> if i == j then [strong [] [subj]] else [subj]
      Nothing -> [subj]
    with_date =
      [ td [ style ["height" => "24px", "width" => "24px"]]
          [ em []
            [
            --text <| "10:50" -- ++ (toString <| Date.fromString msg.header.date)
            text <| toString i --"10:50" -- ++ (toString <| Date.fromString msg.header.date)
            ]
          ]
      , td [] content ]
  in
    tr [style s, onClick (Focus i)] with_date

viewRawMessage : Int -> String -> Html Msg
viewRawMessage i msg =
  div [onClick (Focus i)] [ pre [] [text msg , hr [] [] ]]


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
          List.indexedMap (viewMessage model) msgs



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
    button [onClick ConnectKernel] [text "kernel info"]

quickHTMLButton =
    button [onClick <| Ping error_execute_request_msg] [text "get an error"]

quickHTMLButton2 =
    button [onClick <| Ping fancy_execute_request_msg] [text "get a fancy result"]

quickHTMLButton3 =
    button [onClick <| Ping stdout_execute_request_msg] [text "get some stdout"]

quickHTMLButton4 =
    button [onClick <| Ping basic_execute_request_msg] [text "basic execute (2+2)"]

zip = List.map2 (,)

viewFocused : Model -> Html Msg
viewFocused model =
  case model.focused of
    Just i ->
    let
      msg_pair = List.head <| List.drop i (zip model.msgs model.messages)
      --msg_pair = List.head <| List.drop i model.msgs
      -- = List.head <| List.drop i
    in
    case msg_pair of
      Nothing -> div [] []
      -- Just msg
      Just (msg, raw) ->
        -- TODO: put flexbox styling here
        div [style ["border" => "2px solid", "padding" => "5px", "flex" => "1"]] (renderMsg model msg raw)
       -- , text raw ]
    Nothing -> div [] []

getSubject : Jmsg -> String
getSubject msg =
  let
    state = ": " ++ Maybe.withDefault "" msg.content.execution_state
  in
    "(" ++ msg.channel ++ ") " ++ msg.header.msg_type ++ state

msgFromPart : Jmsg -> String
msgFromPart msg =
  -- all "iopub" message come form the kernel"
  if msg.channel == "iopub" then
  --  msg_type ==  "status" then
    (if msg.header.msg_type == "execute_input" then
    "Client (via Kernel)" else "Kernel"
    ) else
  if String.endsWith "reply" msg.header.msg_type then
    "Kernel" else "Client"

msgToPart : Jmsg -> String
msgToPart msg =
  if msg.channel == "shell" then
    "only us (direct)"
  else
    msg.channel ++ " listeners"


renderMsg : Model -> Jmsg -> String -> List (Html Msg)
renderMsg model msg raw =
  [ table []
    [ tr [] [ td [] [text "Channel:"] , td [] [text (msg.channel)] ]
    , tr [] [ td [] [text "From:"] , td [] [text (msgFromPart msg)] ]
    , tr [] [ td [] [text "To:"] , td [] [text (msgToPart msg)] ]
    , tr [] [ td [] [text "Subject:"] , td [] [text (getSubject msg)] ]
    , tr [] [ td [] [text "Message ID"] , td [] [text (msg.header.msg_id)] ]
    , tr [] [ td [] [text "In-Reply-to:"] , td [] [text (msg.parent_header.msg_id)] ]
    ]
  , hr [] []
  -- , pre [] [text <| encode 2 raw]
  --, pre [] [text <| encode 2 (encodeJmsg msg)]
  -- , text <| encode 2 raw
  , text raw
  -- , text <| "***" ++  msg.header.msg_type ++ ": " ++ (Maybe.withDefault "" msg.content.execution_state) , text <| toString msg
  ]

viewServer model = span []
  [ input [onInput ChangeServer, value model.server] []
  , select [] <| sessionsToOptions model
  ]

sessionToOption : Session -> Html Msg
sessionToOption s = option [onClick (SetActiveSession s)] [text s.notebook.path]

sessionsToOptions : Model -> List (Html Msg)
sessionsToOptions model =
  case model.sessions of
    Success sessions -> List.map sessionToOption sessions
    --_ -> [option [disabled True, selected True] [text ""]]
    _ -> []


