module Main exposing (..)


import BakedMessages exposing (..)
import Char exposing (fromCode, toCode)
import Date
import Html exposing (..)
import Html.Attributes as Attr exposing (..)
import Html.Events exposing (..)
import Http
import JMessages exposing (..)
import JSessions exposing (..)
import Json.Decode exposing (decodeString)
import Json.Encode exposing (encode)
import Keyboard
import Random
import RemoteData exposing (RemoteData(..))
import Task
import Time exposing (Time, now)
import VirtualDom
import WebSocket
import Color exposing (Color, toRgb)
import Regex exposing (HowMany(..), regex)

import Colorbrewer.Qualitative exposing  (..)


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type RawOrRendered
    = Raw
    | Rendered

type UndoAction
  = Deleted (Int, (String, Jmsg))
  | Inserted Int
  | Cleared (List (String, Jmsg))



-- MODEL


type alias Model =
    { input : String
    , msgs : List ( String, Jmsg )
    , index : Maybe Int
    , connectionString : String
    , raw : RawOrRendered
    , focused : Maybe Int
    , bufferedMsg : Maybe (String, Jmsg)
    , undo : List UndoAction
    , server : String
    , sessions : RemoteData Http.Error (List Session)
    , activeSession : Maybe Session
    , status : String
    , seed : Random.Seed

    -- `seed` is used for msg_id generation of outgoing messages, which need to
    -- be unique per Jupyter protocol specification. It is initialized from a
    -- timestamp via the ConnectAPI message on page load.
    , token : String
    }


init : ( Model, Cmd Msg )
init =
    ( { input = ""
      , msgs = []
      , index = Nothing
      , connectionString = ""
      , raw = Raw
      , focused = Nothing
      , bufferedMsg = Nothing
      , undo = []
      , server = "localhost:8888"
      , sessions = NotAsked

      --, sessions = Success sampleSessions
      , activeSession = Nothing
      , status = ""
      , seed = Random.initialSeed 0
      , token = ""
      }
      -- , Cmd.none)
    , Task.perform ConnectAPI now
    )



-- UPDATE


type Msg
    = Input String
    | Send
    | ConnectAPI Time.Time
    | Ping String
    | NewMessage String
    | NewTimeMessage Time String
    | UpdateIndex String
    | GetTimeAndThen (Time -> Msg)
    | ToggleRendered
    | Focus Int
    | NoFocus
    | ChangeServer String
    | NewSessions (Result Http.Error (List Session))
    | SetActiveSession Session
    | RestartActiveSession
    | RestartActiveSessionResult (Result Http.Error ())
    | InterruptActiveSession
    | InterruptActiveSessionResult (Result Http.Error ())
    | DeleteFocusedMessage
    | PopUndoStack
    | YankFocusedMessage
    | PasteBufferedMessage
    | ClearAllMessages
    | KeyMsgDown Keyboard.KeyCode
    | Status String


newMessage str =
    GetTimeAndThen (\time -> NewTimeMessage time str)

--ws_url = "ws://localhost:8888/api/kernels/d341ae22-0258-482b-831a-fa0a0370ffba"
ws_url : Model -> String
ws_url model =
    case model.activeSession of
        Nothing ->
            Debug.log "~~~ uhoh" "http://shouldnothappen"
            -- send message - could not connect to the session msg - perhaps CORS not set up, or the token is missing

        Just s ->
            Debug.log "sending ws to..."
                "ws://"
                ++ model.server
                ++ "/api/kernels/"
                ++ s.kernel.id
                ++ "/channels"
                ++ "?token=" ++ model.token


restart_session_url : Model -> String
restart_session_url model =
    String.join "http:" <| String.split "ws:" <| String.join "/restart?token="  [ model.token ]


interrupt_session_url : Model -> String
interrupt_session_url model =
    String.join "http:" <| String.split "ws:" <| String.join "/interrupt" <| String.split "/channels" (ws_url model)

trailingSlash : Regex.Regex
trailingSlash = regex "/$"

withNothing : Regex.Match -> String
withNothing m = ""

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Input newInput ->
            { model
                | input = newInput
            }
                ! [ Cmd.none ]

        Ping raw_msg ->
            let
                -- decoding from our sample raw messages doesn't work, let's fake it?
                -- try to set the msg_id here, so it's unique...
                ( msg_id, seed ) =
                    Random.step msg_id_generator model.seed

                -- replaces msg_id's value of "" with "6f27aa890d69d98c93535db04bd04de9"
                outgoing =
                    replace "msg_id\": \"" raw_msg ("msg_id\": \"" ++ msg_id)

                new_msgs =
                    case decodeString decodeJmsg outgoing of
                        Ok m ->
                            [ ( outgoing, m ) ]

                        Err x ->
                            Debug.log ("oops..." ++ toString outgoing ++ x) [ ( outgoing, UnknownMessage ) ]

                --  if raw_msg == basic_execute_request_msg then
                --    [basic_execute_request_msg_] else []
            in



            RemoteData.withDefault  (model ! [])
            (RemoteData.map (\s ->
                 { model
                     | msgs = model.msgs ++ new_msgs
                     , seed = seed
                 }
                     ! [ WebSocket.send (ws_url model) outgoing ]) model.sessions)



            --  case model.session of
            --   Success _ =>
            --      { model
            --          | msgs = model.msgs ++ new_msgs
            --          , seed = seed
            --      }
            --          ! [ WebSocket.send (ws_url model) outgoing ]
            --   _ => model ! []

        Send ->
            { model
                | input = ""
                , sessions = Loading
            }
                ! [ WebSocket.send (ws_url model) model.input ]

        NewMessage str ->
            let
                latest =
                    case decodeString decodeJmsg str of
                        -- Ok jmsg -> [(Debug.log "Successfull decoded: " jmsg)]
                        Ok jmsg ->
                            [ ( str, jmsg ) ]

                        Err msg ->
                            let
                                error =
                                    Debug.log "Nope" msg
                            in
                            []
            in
            { model
              --| messages = str :: model.messages
                | msgs = model.msgs ++ latest

                --, last_status = status
            }
                ! [ Cmd.none ]

        GetTimeAndThen successHandler ->
            ( model, Task.perform successHandler now )

        NewTimeMessage time str ->
            model
                --| messages = str :: model.messages
                --     | messages = model.messages ++ [ str ++ formatTime time ]
                ! [ Cmd.none ]

        UpdateIndex str ->
            { model
                | index = Just <| Result.withDefault 0 <| String.toInt str
            }
                ! [ Cmd.none ]

        ToggleRendered ->
            { model
                | raw =
                    case model.raw of
                        Raw ->
                            Rendered

                        Rendered ->
                            Raw
            }
                ! [ Cmd.none ]

        Focus i ->
            { model | focused = Just i } ! [ Cmd.none ]

        NoFocus ->
            { model | focused = Nothing } ! [ Cmd.none ]

        ChangeServer s ->
            let
                (front, token) = case Regex.split All (regex "[?&]token=") s of
                      a :: b :: c ->  (Debug.log "front is" a, b)
                      a :: _ -> (a, "SADDAY_notoken")
                      [] -> ("", "")
                server =  Regex.replace All (regex "http://") withNothing front |> Regex.replace All trailingSlash withNothing

                new_model =
                    { model
                        | server = Debug.log "setting server to" server
                        , token =  Debug.log "setting token  to" token
                        , sessions = Loading
                    }
            in
            new_model ! [ getSession new_model ]

        ConnectAPI x ->
            let
                timestamp =
                    Time.inMilliseconds x |> round

                seed =
                    Random.initialSeed timestamp
            in
            update (ChangeServer model.server) { model | seed = seed, status = ""} -- toString timestamp }

        NewSessions result ->
            let
                new_sessions =
                    -- this result case switch should probably be higher here
                    case result of
                        Ok sessions ->
                            Success (Debug.log "New sessions result: " sessions)

                        Err x ->
                            Debug.log "failure" Failure x
                            -- send message - could not connect to the session msg - perhaps CORS not set up, or the token is missing
            in
            { model
                | sessions = new_sessions
                , activeSession = List.head <| Result.withDefault [] result
            }
                ! [ Cmd.none ]

        SetActiveSession s ->
            case model.activeSession == Just s of
                True ->
                    model ! []

                -- Noop
                False ->
                    update ClearAllMessages { model | activeSession = Just s }

        RestartActiveSession ->
            { model | status = "Restarting" } ! [ getSessionRestart model ]

        RestartActiveSessionResult r ->
            { model | status = "Restart success" } ! [ Cmd.none ]

        InterruptActiveSession ->
            { model | status = "Interrupting" } ! [ getSessionInterrupt model ]

        InterruptActiveSessionResult r ->
            -- let
            --   status = case r of
            --               Ok _  -> "Interrupt sucess"
            --               _ -> "Error"
            -- in
            { model | status = "Interrupted" } ! [ Cmd.none ]

        ClearAllMessages ->
            { model
                | msgs = []
                , focused = Nothing
                , undo = Cleared model.msgs :: model.undo
            } ! [ Cmd.none ]

        DeleteFocusedMessage ->
            dropFocused model ! [ Cmd.none ]

        PopUndoStack ->
            popUndoStack model ! [ Cmd.none ]

        YankFocusedMessage ->
            yankFocused model ! [ Cmd.none ]

        PasteBufferedMessage ->
            pasteBuffered model ! [ Cmd.none ]

        KeyMsgDown code ->
            let
                focused =
                    case fromCode code of
                        'J' ->
                            downMessage model

                        '(' ->
                            downMessage model

                        -- ( is down arrow
                        'K' ->
                            upMessage model

                        '&' ->
                            upMessage model

                        -- & is up arrow
                        x ->
                            let
                                code =
                                    Debug.log "keycode" x
                            in
                            model.focused

                ( new_model, commands ) =
                    case fromCode code of
                        'C' ->
                            update ClearAllMessages model

                        'R' ->
                            --update (Ping resource_info_request_msg) model
                            update ToggleRendered model

                        'T' ->
                            update ToggleRendered model

                        'S' ->
                            update (Ping sleep_request_msg) model

                        '¾' ->
                            update RestartActiveSession model

                        -- ¾ is .
                        'I' ->
                            update InterruptActiveSession model

                        'D' ->
                            update DeleteFocusedMessage model

                        'U' ->
                            update PopUndoStack model

                        'Y' ->
                            update YankFocusedMessage model

                        'P' ->
                            update PasteBufferedMessage model

                        _ ->
                            model ! []
            in
            { new_model | focused = focused } ! [ commands ]

        Status s ->
            { model | status = s } ! []


downMessage : Model -> Maybe Int
downMessage model =
    case model.focused of
        Nothing ->
            Just 0

        Just i ->
            if i + 1 == List.length model.msgs then
                Nothing
            else
                Just (i + 1)


upMessage : Model -> Maybe Int
upMessage model =
    case model.focused of
        Nothing ->
            Just (List.length model.msgs - 1)

        --Just i -> Just (i-1)
        Just i ->
            if i - 1 == -1 then
                Nothing
            else
                Just (i - 1)



-- Timezone offset (relative to UTC)


tz =
    -7


formatTime : Time -> String
formatTime t =
    String.concat <|
        List.intersperse ":" <|
            List.map toString
                [ floor (Time.inHours t) % 24 + tz
                , floor (Time.inMinutes t) % 60
                , floor (Time.inSeconds t) % 60
                ]

basic_url : Model -> String
basic_url model = "http://" ++ model.server ++ "/" ++ "?token=" ++ model.token

api_url : Model -> String
api_url model =
    -- TODO: this is brittle - we should check if there's already a leading http://
    -- in the url and not add it to the front in that case
    -- TODO: support tokens and password
    "http://" ++ model.server ++ "/api/sessions" ++ "?token=" ++ model.token


getSession : Model -> Cmd Msg
getSession model =
    let
        request =
            Http.get (Debug.log "Sessions API url: " (api_url model)) decodeSessions
    in
    Http.send NewSessions request


getSessionRestart : Model -> Cmd Msg
getSessionRestart model =
    let
        request =
            Debug.log "calling url" (restart_session_request model)

        --Http.post (restart_session_url model) Http.emptyBody Json.Decode.value
    in
    Http.send RestartActiveSessionResult request


getSessionInterrupt : Model -> Cmd Msg
getSessionInterrupt model =
    Http.send InterruptActiveSessionResult (interrupt_session_request model)


restart_session_request model =
    Http.request
        { method = "POST"
        , headers = []

        -- , headers = [xsrf_header] -- disable_check_xsrf=True and you don't need this.
        , url = restart_session_url model
        , body = Http.emptyBody
        , withCredentials = True
        , expect = Http.expectStringResponse (\_ -> Ok ())
        , timeout = Nothing
        }


interrupt_session_request model =
    Http.request
        { method = "POST"
        , headers = []

        -- , headers = [xsrf_header] -- disable_check_xsrf=True and you don't need this.
        , url = interrupt_session_url model
        , body = Http.emptyBody
        , withCredentials = True
        , expect = Http.expectStringResponse (\_ -> Ok ())
        , timeout = Nothing
        }



-- --NotebookApp.disable_check_xsrf=True eliminated the need for this


xsrf_cookie =
    Http.header "Cookie" "_xsrf=2|30bc50cd|8c06faa1a9c8b6336386346ae8415c04|1505762830"


xsrf_header =
    Http.header "X-XSRFToken" "2|30bc50cd|8c06faa1a9c8b6336386346ae8415c04|1505762830"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.activeSession of
        Nothing ->
            Sub.none

        _ ->
            Sub.batch
                [ WebSocket.listen (ws_url model) NewMessage
                , Keyboard.downs KeyMsgDown
                ]



-- VIEW


(=>) =
    (,)


view : Model -> Html Msg
view model =
    div
        [ style
            [ "display" => "flex"
            , "margin" => "0"
            , "flex-direction" => "column"
            , "min-height" => "100vh"
            , "flex" => "1" 
            ]
        ]
        [ viewStatus model
        , div [style []]
            [ toggleRenderedStatus model
            , clearSelectionButton
            , kernelInfoButton
            , quickHTMLButton4
            , quickHTMLButton
            , quickHTMLButton3
            , quickHTMLButton2
            , quickHTMLButton6
            , quickHTMLButton5
            ]
        , div [ style [ "display" => "flex", "flex-direction" => "row", "max-height" => "87vh"] ]
            [  div [style ["overflow" => "auto"]] [table [ style ["min-width" =>
            "200px"] ] (viewValidMessages model)]
            , viewFocused model
            ]
        -- , input [ onInput Input ] []
        -- , button [ onClick Send ] [ text "Send" ]

        -- , button [ onClick <| newMessage "--- mark --- " ] [ text "add marker" ]
        , div [ style [ "flex" => "1" ] ] []
        , button [ onClick ClearAllMessages ] [ text "(C)lear all messages" ]

        --<| "--- mark --- " ++ [(toString <| Task.perform <| \a ->  Time.now )] [text "Add Marker"]
        -- , viewTimeSlider model
        -- , viewTimeSlider model
        , viewTimeSlider model
        ]


viewStatus : Model -> Html Msg
viewStatus model =
    let
        ( color, message ) =
            case model.sessions of
                NotAsked ->
                    ( "red", "Not connected" )

                Loading ->
                    ( "yellow", "Loading..." )

                Success s ->
                  case s of
                    a::b ->
                      ( "green", " Active session" )
                    nil ->
                      ( "yellow", "This server has no active sessions. " )

                Failure x ->
                    ( "red", "Failed to connect to Notebook server" )
    in
    div [ style [ "display" => "flex" , "backgroundColor" => color ]
        , onClick (ChangeServer model.server)
        ] [ viewServer model, viewActiveSession message, viewStatusText model ]


viewActiveSession : String -> Html Msg
viewActiveSession statusText =
    span
        [ style [ "style" => "box" ] ]
        [ spacer
        , text statusText
        , spacer
        , button [ onClick RestartActiveSession ] [ text "Restart (.)" ]
        , button [ onClick InterruptActiveSession ] [ text "(i)nterrupt" ]
        ]


spacer : Html Msg
spacer =
    span [ style [ "width" => "30px" ] ] []


viewStatusText : Model -> Html Msg
viewStatusText model =
    span [ style [ "background-color" => "white", "flex" => "2" ] ] [ text model.status ]



-- TODO: take out
viewMessage : Model -> Int -> Jmsg -> Html Msg
viewMessage model i msg = case msg of
  Known msg -> viewMessage_ model i msg
  UnknownMessage -> let s = []
    in
      tr [ style s, onClick (Focus i) ]
          -- TODO : clean up this stling, unify with 'with_date` below
              [ td [] [], td [ style [ "height" => "24px", "width" => "24px" ]] [text "Unknown"] ]

viewMessage_ : Model -> Int -> Jmsg_ -> Html Msg
viewMessage_ model i msg =
    let
        s = case model.focused of
          Just j ->
              if i == j then
                  [ "background-color" => msg2color model msg ]
              else
                  [ "background-color" => msg2colorMuted model msg ]

          Nothing ->
              [ "background-color" => msg2color model msg]

        subj =
            text <| getSubject msg

        (content, ii) =
            case model.focused of
                Just j ->
                    if i == j then
                        ([ strong [] [ subj ] ], strong [] [text <| toString i])
                    else
                        ([ subj ], text <| toString i)

                Nothing ->
                    ([ subj ], text <| toString i)

        with_date =
            [ td [ style [ "height" => "24px", "width" => "24px" ] ]
                 [ em []
                     [ --text <| "10:50" -- ++ (toString <| Date.fromString msg.header.date)
                       --text <| toString i --"10:50" -- ++ (toString <| Date.fromString msg.header.date)
                       -- ii --"10:50" -- ++ (toStringHMS <| Date.fromString msg.header.date)
                       ii
                     ]
                 ]
            , td [] content
            , (toHMS <| Date.fromString msg.header.date)
            ]
    in
    tr [ style <| s ++ [ "cursor" => "pointer"], onClick (Focus i) ] with_date

toHMS : Result String Date.Date -> Html Msg
toHMS d =
  let (s, hover) =
    case d of
      Ok d ->
        (List.map toString [Date.hour d, Date.minute d, Date.second d,
        Date.millisecond d]  |>
        String.join ":", "")
      Err e ->
        ("???", e)
  in
    span [title hover] [text s]


{- This is kind of fugly, but works -}
color2text : Color -> String
color2text color
  = let c = toRgb color
  in
    "rgb("
    ++ toString c.red ++ ","
    ++ toString c.green ++ ","
    ++ toString c.blue ++ ")"

{- TODO: turn this into a case switch once we properly differentiate the different kinds of Jmsgs
-}
msg2color : model -> Jmsg_ -> String
msg2color m j =
  let color =
    if j.header.msg_type == "execute_request" then
      paired12_0
    else if j.header.msg_type == "execute_reply" then
      paired12_1
    else if j.header.msg_type == "execute_input" then
      paired12_2
    else if j.header.msg_type == "execute_result" then
      paired12_3
    else if j.header.msg_type == "error" then
      paired12_4
    else if j.header.msg_type == "stream" then
      paired12_11
    else
      paired12_10
  in
    color2text color

msg2colorMuted : model -> Jmsg_ -> String
msg2colorMuted m j = let
    c = msg2color m j
    with_a = replace "rgb" c "rgba"
  in
    replace ")" with_a ", 0.5)"

viewRawMessage : Int -> String -> Html Msg
viewRawMessage i msg =
    div [ onClick (Focus i) ] [ pre [] [ text msg, hr [] [] ] ]


viewValidMessages : Model -> List (Html Msg)
viewValidMessages model =
  let
    msgs = case model.index of
        Nothing -> model.msgs
        Just i -> List.take i model.msgs
  in
    List.indexedMap (\index ( string, message ) ->
      viewMessage model index message) msgs

dropFocused : Model -> Model
dropFocused m  =
  let
    mNext = yankFocused m
    msgs = case m.focused of
      Nothing -> m.msgs
      Just i ->
        if i == 0 then
          List.drop 1 m.msgs
        else
          List.take i m.msgs ++ List.drop (i+1) m.msgs
    undo = case m.focused of
      Nothing -> m.undo
      Just i ->
        let
          focusedMsg = if i == 0 then
            List.head m.msgs
          else
            List.head (List.drop i m.msgs)
        in
          case focusedMsg of
            Nothing -> m.undo
            Just msg -> Deleted (i, msg) :: m.undo
  in
    { mNext
        | msgs = msgs
        , focused = inRange (List.length msgs) m.focused
        , undo = undo
     }

inRange : Int -> Maybe Int -> Maybe Int
inRange max cur = if max == 0 then Nothing
  else case cur of
    Nothing -> Nothing
    Just i ->
      if i < max then
        Just i
      else
        Just (max-1)

yankFocused : Model -> Model
yankFocused m =
  case m.focused of
    Nothing -> m
    Just i -> {m | bufferedMsg = List.head <| List.drop i m.msgs }

pasteBuffered : Model -> Model
pasteBuffered m =
  case m.bufferedMsg of
    Nothing -> m
    Just msg ->
      case m.focused of
        Nothing ->
          { m | msgs = msg :: m.msgs
              , undo = Inserted 0 :: m.undo
          }
        Just i ->
          { m | msgs = (List.take (i+1) m.msgs) ++ msg :: (List.drop (i+1) m.msgs)
              , undo = Inserted (i+1) :: m.undo
          }

popUndoStack : Model -> Model
popUndoStack m =
  let (msgs, undo) =
    case m.undo of
      x :: xs -> case x of
        Deleted (i, msg) ->
          if i == 0 then (msg :: m.msgs, xs)
          else ((List.take i m.msgs) ++ msg :: List.drop i m.msgs, xs)
        Inserted i ->
          (List.take i m.msgs ++ List.drop (i+1) m.msgs, xs)
        Cleared msgs ->
          (msgs, xs)

      _ -> (m.msgs, m.undo)
  in
  { m | undo = undo, msgs = msgs }

viewTimeSlider : Model -> Html Msg
viewTimeSlider model =
    let
        len =
            List.length model.msgs
    in
    footer []
        [ input
            [ type_ "range"
            , Attr.min "0"
            , Attr.max <| toString len
            , value <| toString <| Maybe.withDefault len model.index
            , onInput UpdateIndex
            , style [ "width" => "96%" ]
            ]
            [ text "hallo" ]
        ]


toggleRenderedStatus : Model -> Html Msg
toggleRenderedStatus model =
    let
        nextToggleValue =
            case model.raw of
                Raw ->
                    "(R)endered"

                Rendered ->
                    "(R)aw"
    in
    button [ onClick ToggleRendered ] [ text nextToggleValue ]

clearSelectionButton : Html Msg
clearSelectionButton = button [ onClick NoFocus ]  [ text "Clear Selection" ]

kernelInfoButton : Html Msg
kernelInfoButton =
    button [ onClick <| Ping kernel_info_request_msg ] [ text "kernel info" ]


quickHTMLButton =
    button [ onClick <| Ping error_execute_request_msg ] [ text "get an error" ]


quickHTMLButton2 =
    button [ onClick <| Ping fancy_execute_request_msg ] [ text "get a fancy result" ]


quickHTMLButton3 =
    button [ onClick <| Ping stdout_execute_request_msg ] [ text "get some stdout" ]


quickHTMLButton4 =
    button [ onClick <| Ping basic_execute_request_msg ] [ text "basic execute (2+2)" ]


quickHTMLButton6 =
    button [ onClick <| Ping sleep_request_msg ] [ text "(s)leep for 10 seconds" ]


quickHTMLButton5 =
    button
        [ onClick <| Ping resource_info_request_msg
        , onMouseOver <| Status "Requires ivanov's ipykernel branch"
        , onMouseOut <| Status ""
        ]
        [ text "resource info request" ]


zip =
    List.map2 (,)


viewFocused : Model -> Html Msg
viewFocused model =
    case model.focused of
        Just i ->
            let
                msg_pair =
                    List.head <| List.drop i model.msgs

                --msg_pair = List.head <| List.drop i model.msgs
                -- = List.head <| List.drop i
            in
            case msg_pair of
                Nothing ->
                    div [] []

                -- Just msg
                Just ( raw, msg ) ->
                    -- TODO: put flexbox styling here
                    div [ style [ "border" => "2px solid", "padding" => "5px", "flex" => "1", "overflow" => "auto"] ] (renderMsg model msg raw)

        -- , text raw ]
        Nothing ->
            div [] []


getSubject : Jmsg_ -> String
getSubject msg =
    let
        state =
            ": " ++ Maybe.withDefault "" msg.content.execution_state
    in
    "(" ++ msg.channel ++ ") " ++ msg.header.msg_type ++ state


msgFromPart : Jmsg_ -> String
msgFromPart msg =
    -- all "iopub" message come form the kernel"
    if msg.channel == "iopub" then
        --  msg_type ==  "status" then
        if msg.header.msg_type == "execute_input" then
            "Client: " ++ msg.header.username ++ " (via Kernel)"
        else
            "Kernel"
    else if String.endsWith "reply" msg.header.msg_type then
        "Kernel"
    else
        "Client: " ++ msg.header.username


msgToPart : Jmsg_ -> String
msgToPart msg =
    if msg.channel == "shell" then
        if String.endsWith "_request" msg.header.msg_type then
          "The kernel"
        else
          "only us (direct)"
    else
        msg.channel ++ " listeners"

renderMsg : Model -> Jmsg -> String -> List (Html Msg)
renderMsg model msg raw = case msg of
  UnknownMessage -> [table [] [], hr [] [], text raw]
  Known msg -> renderMsg_ model msg raw

renderMsg_: Model -> Jmsg_ -> String -> List (Html Msg)
renderMsg_ model msg raw =
    [ table []
        [ tr [] [ td [] [ text "Channel:" ], td [] [ text msg.channel ] ]
        , tr [] [ td [] [ text "From:" ], td [] [ text (msgFromPart msg) ] ]
        , tr [] [ td [] [ text "To:" ], td [] [ text (msgToPart msg) ] ]
        , tr [] [ td [] [ text "Subject:" ], td [] [ text (getSubject msg) ] ]
        , tr [] [ td [] [ text "Message ID" ], td [] [ text msg.header.msg_id ] ]
        , tr [] [ td [] [ text "In-Reply-to:" ], td [] [ text msg.parent_header.msg_id ] ]
        ]
    , hr [] []

    -- , pre [] [text <| encode 2 raw]
    --, pre [] [text <| encode 2 (encodeJmsg msg)]
    -- , text <| encode 2 raw
    , renderMimeBundles msg
    , renderException msg
    , hr [] []
    , case model.raw of
        Raw -> text raw
        Rendered -> text ""

    -- , text <| "***" ++  msg.header.msg_type ++ ": " ++ (Maybe.withDefault " (1 no exec state)" msg.content.execution_state) , text <| toString msg
    ]

-- renderMimeBundles : Jmsg_ -> Html Msg

renderMimeBundles : Jmsg_ -> Html Msg
renderMimeBundles msg =
    case msg.content.data of
        Nothing ->
            div [ innerHtml "No <b> content data</b> :\\" ] []

        Just data ->
            div []
                [  asHtml data.text_html  "text/html"
                ,  asHtml data.image_png  "image/png"
                ,  asHtml data.text_plain  "plain"
                -- ,  asHtml data.code  "code"
                ]

asHtml : Maybe String -> String -> Html Msg
asHtml c name  =
    case c of
        Nothing ->
            div [] []

        Just s ->
          if name=="text/html" then
            div [innerHtml (name ++ ": " ++ s)] []
          else if name=="image/png" then
            --div [innerHtml ("<img src=\"data:image/png;base64," ++ s ++ "\">") ] []
            div [] [text name, text ": ", img [ src ("data:image/png;base64," ++ s)] []]
          else
            div [] [text name, text ": ", text s]


innerHtml : String -> Html.Attribute Msg
innerHtml s =
    VirtualDom.property "innerHTML" <| Json.Encode.string s

renderException : Jmsg_ -> Html Msg
renderException msg =
  let
    tb = msg.content.traceback
  in
    tbAsHtml tb

tbAsHtml : Maybe (List String) -> Html Msg
tbAsHtml tb =
  case tb of
    Nothing -> div [] []
    Just strings -> asHtml (Just (String.join "" strings)) "Traceback"

viewServer : Model -> Html Msg
viewServer model =
    span []
        [ input [ onInput ChangeServer, value (basic_url model) ] []
        , select [] <| sessionsToOptions model
        ]


sessionToOption : Session -> Html Msg
sessionToOption s =
    option [ onClick (SetActiveSession s) ] [ text s.notebook.path ]


sessionsToOptions : Model -> List (Html Msg)
sessionsToOptions model =
    case model.sessions of
        Success sessions ->
          case sessions of
            a::b ->
              (List.map sessionToOption sessions)
            nil ->
               [option [disabled True, selected True] [text "oops"]]
            --[option [ onClick (ChangeServer model.server) ] [text "fetch sessions"]]

        --_ -> [option [disabled True, selected True] [text ""]]
        _ ->[option [disabled True, selected True] [text "damn"]]
            --[]


{-| Generate a random hex character (one of '0'-'9' and 'a'-'f')
-}
randomHex : Random.Generator Char
randomHex =
    Random.map
        (\x ->
            case x < 10 of
                True ->
                    Char.fromCode (x + 48)

                -- 48 is '0'
                False ->
                    Char.fromCode (x + 87)
        )
        -- 97 is 'a'
        (Random.int 0 15)



-- Generator values are inclusive [0,1,...14,15]


{-| Generate a 32 hex character string

The classic Jupyter Notebook javascript generates a UUID version 4 string here,
but the protocol does not require this, so we just do a best effort to immitate
the notebook behavior.

-}
msg_id_generator : Random.Generator String
msg_id_generator =
    Random.list 32 randomHex |> Random.map (\x -> String.fromList x)



{- Replace `x` in `y` with `z` -}


replace : String -> String -> String -> String
replace x y z =
    String.split x y |> String.join z
