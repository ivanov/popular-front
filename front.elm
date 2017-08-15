import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import RemoteData exposing (RemoteData(..))
import WebSocket
import Http

--import JupyterMessages exposing (..)

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

type alias Sessions = String

-- MODEL

type alias Model =
  { input : String
  , messages : List String
  , sessions : RemoteData Http.Error (List Sessions)
  , index : Maybe Int
  }


init : (Model, Cmd Msg)
init =
  (Model "" ["hey", "how", "are", " you"] NotAsked Nothing, Cmd.none)


-- UPDATE

type Msg
  = Input String
  | Send
  | NewMessage String


ws_url : String
--ws_url = "ws://localhost:8888/api/kernels/d341ae22-0258-482b-831a-fa0a0370ffba"
--ws_url = "http://localhost:8888/api/kernels/d341ae22-0258-482b-831a-fa0a0370ffba/channels?session_id=6CCE28259904425785B76A7D45D9EB26"
--ws_url = "ws://localhost:8080/echo"
--ws_url = "ws://localhost:8888/api/kernels/08f00356-1bbc-45ef-99ca-8163462a5ee7"
--ws_url = "ws://localhost:8888/api/kernels/57cd23b2-e6b1-4458-93ed-2c513b0442ca"
-- ws_url = "ws://localhost:8888/api/kernels/57cd23b2-e6b1-4458-93ed-2c513b0442ca/channels?session_id=6A5BB323BD6F41A3B95860E4441716C1"
ws_url = "ws://localhost:8888/api/kernels/57cd23b2-e6b1-4458-93ed-2c513b0442ca/channels"


update : Msg -> Model -> (Model, Cmd Msg)
--update msg {input, messages, sessions} =
update msg model =
  case msg of
    Input newInput ->
      { model
      | input = newInput
      } ! [ Cmd.none ]

    Send ->
      { model
      | input = ""
      } ! [ WebSocket.send ws_url model.input ]

    NewMessage str ->
    { model
    | messages = str :: model.messages
    } ! [ Cmd.none ]


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  WebSocket.listen ws_url NewMessage


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ div [] <| viewValidMessages model
    , input [onInput Input] []
    , button [onClick Send] [text "Send"]
    ]


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
