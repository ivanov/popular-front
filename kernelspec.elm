import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, on)
import Http
import Json.Decode exposing (field, int, oneOf, string, dict)
import Json.Encode exposing (encode)
import Task
import JSessions exposing (..)

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

appTypes = [ "Blank", "Equity Screening", "Fake report", "Chart"]

-- MODEL
type alias Model =
  { fullName: Maybe String
  , templateType: Maybe String
  , apiResponse: Maybe KernelSpecAPI -- TODO: switch to RemoteData?
  , sessionNumber: Int
  }

init : ( Model, Cmd Msg )
init = (
  { fullName = Nothing
  , templateType = List.head appTypes
  , apiResponse = Nothing
  , sessionNumber = 0
  }, Cmd.batch [send (ChangeType "default"), send (StartNewKernel "default")])

-- from https://medium.com/elm-shorts/how-to-turn-a-msg-into-a-cmd-msg-in-elm-5dd095175d84
send : Msg -> Cmd Msg
send msg = Task.succeed msg
  |> Task.perform identity

-- UPDATE
type Msg
    = None
    | ChangeName String
    | ChangeType String
    | FetchKernelSpecAPI (Result Http.Error KernelSpecAPI)
    | StartNewKernel String
    | SessionCreated (Result Http.Error Session)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let x = Debug.log (toString model) "update..." in
  case msg of
    ChangeName s ->
      { model | fullName = Just s} ! [Cmd.none]
    ChangeType s ->
      { model | templateType = Just s} ! [getNotebook model]
    FetchKernelSpecAPI result ->
      let
        notebook = case result of
          Ok nb -> Just nb
          Err x -> Debug.log ("couldn't load nb" ++ toString x) Nothing
      in
        { model | apiResponse = notebook } ! [Cmd.none]
    StartNewKernel kernel_name ->
      { model | sessionNumber = model.sessionNumber + 1 } ! [postSession model kernel_name]
    SessionCreated result ->
      let
        maybe_res = case result of
          Ok s -> Debug.log ("Successful session!"++toString s) (Just s)
          Err x -> Debug.log ("couldn't load nb" ++ toString x) Nothing
          -- TODO: add a message about this
      in
        model ! [Cmd.none]
    None -> (model, Cmd.none)

--onChange = on "change" Json.map

-- VIEW


(=>) = (,)

view : Model -> Html Msg
view model = div []
  [ viewName model
  , br [] []
  , viewKernelSpecList model
  , viewActiveKernelSpec model
  , br [] []
  , viewLaunchKernelButton model
  , br [] []
  , viewDefault model
  , div [] [text <| toString model]]

viewName : Model -> Html Msg
viewName model = let n = Maybe.withDefault "Your name" model.fullName in
  input [ style [("background-color" => "red")]
        , name "fullName"
        , value n
        , onInput ChangeName ] []

viewKernelSpecList : Model -> Html Msg
viewKernelSpecList model =
  select
    [ size 4
    , onInput ChangeType
    ]
    <| List.map (optFor model) (getKernelSpecNameList model)

viewActiveKernelSpec : Model -> Html Msg
viewActiveKernelSpec model =
  div [] [ text
    <| toString
    --<| Maybe.withDefault  ""
    <| Dict.get (Maybe.withDefault "default" model.templateType)
    <| (case model.apiResponse of
          Nothing -> Dict.empty
          Just ks -> ks.kernelSpecs)
  ]

viewDefault : Model -> Html Msg
viewDefault model =
  case model.apiResponse of
    Nothing -> br [] []
    Just api -> div [] [ text <| "Default: " ++ api.default ]

viewLaunchKernelButton model =
  let name = Maybe.withDefault "default" model.templateType
  in
  button [onClick (StartNewKernel name)] [ text
    <| "Launch " ++ toString name
  ]


getKernelSpecNameList : Model -> List String
getKernelSpecNameList model =
  case model.apiResponse of
    Nothing -> []
    Just ks -> Dict.keys ks.kernelSpecs

optFor : Model -> String -> Html Msg
optFor model s = option [ value s, selected (Just s == model.templateType) ] [text s]

getNotebook : Model -> Cmd Msg
getNotebook model =
    let
        request =
            Http.get (Debug.log "Sessions API url: " "http://localhost:8888/api/kernelspecs") decodeKernelSpecAPI
    in
    Http.send FetchKernelSpecAPI request

session_api_url : String
session_api_url = "http://localhost:8888/api/sessions"


postSession : Model -> String -> Cmd Msg
postSession model name =
  Http.post session_api_url (makeSession model name) decodeSession
    |> Http.send SessionCreated

-- createPostRequest : Model -> String -> Http.Request SessionReq
makeSession : Model -> String -> Http.Body
makeSession model name =
  Http.jsonBody (encodeSessionReq
    (makeSessionReq ("something" ++ (toString model.sessionNumber)) name)
  )


type alias KernelSpecAPI =
  { default : String
  , kernelSpecs : Dict String KernelSpec
  }

type alias KernelSpec =
  { name : String
  , spec : KernelSpecSpec
  , resources : Dict String String
  }

type alias KernelSpecSpec =
  { argv : List String
  --, env :  Dict String String
  , display_name : String
  , language: String
  , interrupt_mode: String -- when did this get introduced?
  --, metadata: Dict J
  }

decodeKernelSpecAPI : Json.Decode.Decoder KernelSpecAPI
decodeKernelSpecAPI =
  Json.Decode.map2 KernelSpecAPI
    (field "default" string)
    (field "kernelspecs" (dict decodeKernelSpec))

decodeKernelSpec : Json.Decode.Decoder KernelSpec
decodeKernelSpec =
  Json.Decode.map3 KernelSpec
    (field "name" string)
    (field "spec" decodeKernelSpecSpec)
    (field "resources" (dict string))



decodeKernelSpecSpec : Json.Decode.Decoder KernelSpecSpec
decodeKernelSpecSpec =
  Json.Decode.map4 KernelSpecSpec
    (field "argv" (Json.Decode.list string))
    (field "display_name" string)
    (field "language" string)
    (field "interrupt_mode" string)



-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model = Sub.none
