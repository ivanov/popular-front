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



-- MODEL


type alias Model =
    { input : String
    , msgs : List ( String, Jmsg )
    , index : Maybe Int
    , connectionString : String
    , raw : RawOrRendered
    , focused : Maybe Int
    , server : String
    , sessions : RemoteData Http.Error (List Session)
    , activeSession : Maybe Session
    , status : String
    , seed : Random.Seed

    -- `seed` is used for msg_id generation of outgoing messages, which need to
    -- be unique per Jupyter protocol specification. It is initialized from a
    -- timestamp via the ConnectAPI message on page load.
    }


init : ( Model, Cmd Msg )
init =
    ( { input = ""
      , msgs = []
      , index = Nothing
      , connectionString = ""
      , raw = Rendered
      , focused = Nothing
      , server = "localhost:8888"
      , sessions = NotAsked

      --, sessions = Success sampleSessions
      , activeSession = Nothing
      , status = ""
      , seed = Random.initialSeed 0
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
    | ChangeServer String
    | NewSessions (Result Http.Error (List Session))
    | SetActiveSession Session
    | RestartActiveSession
    | RestartActiveSessionResult (Result Http.Error ())
    | InterruptActiveSession
    | InterruptActiveSessionResult (Result Http.Error ())
    | ClearAllMessages
    | KeyMsgDown Keyboard.KeyCode
    | Status String


newMessage str =
    GetTimeAndThen (\time -> NewTimeMessage time str)

token : String
token = "038eaee1ae5b0b07d503ec1490f2e01945f686b5c8181557"

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
                ++ "?token=" ++ token


restart_session_url : Model -> String
restart_session_url model =
    String.join "http:" <| String.split "ws:" <| String.join "/restart?token=" <| String.split "/channels" (ws_url model)


interrupt_session_url : Model -> String
interrupt_session_url model =
    String.join "http:" <| String.split "ws:" <| String.join "/interrupt" <| String.split "/channels" (ws_url model)


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
            { model
                | focused =
                    case Just i == model.focused of
                        True ->
                            Nothing

                        False ->
                            Just i
            }
                ! [ Cmd.none ]

        ChangeServer s ->
            let
                new_model =
                    { model
                        | server = s
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
            update (ChangeServer model.server) { model | seed = seed, status = toString timestamp }

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
            { model | msgs = [], focused = Nothing } ! [ Cmd.none ]

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
                            update (Ping resource_info_request_msg) model
                        
                        'T' ->
                            update ToggleRendered model

                        'S' ->
                            update (Ping sleep_request_msg) model

                        '¾' ->
                            update RestartActiveSession model

                        -- ¾ is .
                        'I' ->
                            update InterruptActiveSession model

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


api_url : Model -> String
api_url model =
    -- TODO: this is brittle - we should check if there's already a leading http://
    -- in the url and not add it to the front in that case
    -- TODO: support tokens and password
    "http://" ++ model.server ++ "/api/sessions" ++ "?token=" ++ token


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
            ]
        ]
        [ viewStatus model
        , div []
            [ toggleRenderedStatus model
            , kernelInfoButton
            , quickHTMLButton4
            , quickHTMLButton
            , quickHTMLButton3
            , quickHTMLButton2
            , quickHTMLButton6
            , quickHTMLButton5
            ]
        , div [ style [ "display" => "flex", "flex-direction" => "row", "max-height" => "87vh"] ]
            [  div [style ["overflow" => "auto"]] [table [ style [] ] (viewValidMessages model)]
            , viewFocused model
            ]
        -- , input [ onInput Input ] []
        -- , button [ onClick Send ] [ text "Send" ]

        -- , button [ onClick <| newMessage "--- mark --- " ] [ text "add marker" ]
        , button [ onClick ClearAllMessages ] [ text "(C)lear all messages" ]

        --<| "--- mark --- " ++ [(toString <| Task.perform <| \a ->  Time.now )] [text "Add Marker"]
        , div [ style [ "flex" => "1" ] ] []
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

                Success _ ->
                    ( "green", "Connected" )

                Failure x ->
                    ( "red", "Failed to connect" )
    in
    div [ style [ "display" => "flex", "backgroundColor" => color ] ] [ viewServer model, viewActiveSession message, viewStatusText model ]


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
              [ td [ style [ "height" => "24px", "width" => "24px" ]] [text "Unknown"] ]

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

        content =
            case model.focused of
                Just j ->
                    if i == j then
                        [ strong [] [ subj ] ]
                    else
                        [ subj ]

                Nothing ->
                    [ subj ]

        with_date =
            [ td [ style [ "height" => "24px", "width" => "24px" ] ]
                [ em []
                    [ --text <| "10:50" -- ++ (toString <| Date.fromString msg.header.date)
                      text <| toString i --"10:50" -- ++ (toString <| Date.fromString msg.header.date)
                    ]
                ]
            , td [] content
            ]
    in
    tr [ style s, onClick (Focus i) ] with_date


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
    case model.raw of
        Raw ->
            let
                msgs =
                    case model.index of
                        Nothing ->
                            List.map Tuple.first model.msgs

                        Just i ->
                            List.take i model.msgs
                                |> List.map Tuple.first
            in
            List.indexedMap viewRawMessage msgs

        Rendered ->
            let
                msgs =
                    case model.index of
                        Nothing ->
                            model.msgs

                        Just i ->
                            List.take i model.msgs
            in
            List.indexedMap (\index ( string, message ) -> viewMessage model index message) msgs


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
                    "Rendered"

                Rendered ->
                    "Raw"
    in
    button [ onClick ToggleRendered ] [ text nextToggleValue ]


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
        [ text "(r)esource info request" ]


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
            "Client (via Kernel)"
        else
            "Kernel"
    else if String.endsWith "reply" msg.header.msg_type then
        "Kernel"
    else
        "Client"


msgToPart : Jmsg_ -> String
msgToPart msg =
    if msg.channel == "shell" then
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
    , text raw

    -- , text <| "***" ++  msg.header.msg_type ++ ": " ++ (Maybe.withDefault "" msg.content.execution_state) , text <| toString msg
    ]

-- renderMimeBundles : Jmsg_ -> Html Msg

renderMimeBundles : Jmsg_ -> Html Msg
renderMimeBundles msg =
    case msg.content.data of
        Nothing ->
            div [ innerHtml "No <b> content</b> :\\" ] []

        Just data ->
            div []
                [ div [ asHtml data.text_html ] [ text "text/html" ]
                , div [ asHtml data.text_plain ] [ text "plain" ]
                , div [ asHtml data.code ] [ text "code" ]
                ]


asHtml : Maybe String -> Attribute Msg
asHtml c =
    case c of
        Nothing ->
            innerHtml ""

        Just s ->
            innerHtml s


innerHtml : String -> Html.Attribute Msg
innerHtml s =
    VirtualDom.property "innerHTML" <| Json.Encode.string s


viewServer model =
    span []
        [ input [ onInput ChangeServer, value model.server ] []
        , select [] <| sessionsToOptions model
        ]


sessionToOption : Session -> Html Msg
sessionToOption s =
    option [ onClick (SetActiveSession s) ] [ text s.notebook.path ]


sessionsToOptions : Model -> List (Html Msg)
sessionsToOptions model =
    case model.sessions of
        Success sessions ->
            List.map sessionToOption sessions

        --_ -> [option [disabled True, selected True] [text ""]]
        _ ->
            []


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
