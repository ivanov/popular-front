import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, on)
import Http
import Json.Decode as D exposing (field, int, oneOf, string, dict)
import Json.Encode as E exposing (encode)
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
  { serverUrl: String
  , templateType: Maybe String
  , apiResponse: Maybe KernelSpecAPI -- TODO: switch to RemoteData?
  , sessionNumber: Int
  , params: Dict String String
  , msg: Maybe String
  }

init : ( Model, Cmd Msg )
init = (
  { serverUrl = "http://localhost:8888"
  , templateType = List.head appTypes
  , apiResponse = Nothing
  , sessionNumber = 0
  , params = Dict.empty
  , msg = Nothing
  }, Cmd.batch [send RefetchUrl])

-- from https://medium.com/elm-shorts/how-to-turn-a-msg-into-a-cmd-msg-in-elm-5dd095175d84
send : Msg -> Cmd Msg
send msg = Task.succeed msg
  |> Task.perform identity

-- UPDATE
type Msg
    = None
    | ChangeUrl String
    | RefetchUrl
    | ChangeType String
    | FetchKernelSpecAPI (Result Http.Error KernelSpecAPI)
    | StartNewKernel String
    | SessionCreated (Result Http.Error Session)
    | ChangeParam String String

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let x = Debug.log (toString model) "update..." in
  case msg of
    ChangeUrl s ->
      { model
        | serverUrl = String.trim s
      } ! [Cmd.none]
    RefetchUrl ->
      { model
        | apiResponse = Nothing
        , templateType = Nothing
      } ! [getNotebook model]
    ChangeType s ->
      { model | templateType = Just s} ! [Cmd.none]
    FetchKernelSpecAPI result ->
      let
        err_msg = "Couldn't fetch kernelspecs: "
        (api, msg) = case result of
          Ok api -> (Just api, Nothing)
          Err x -> (Debug.log (err_msg ++ toString x) Nothing, Just (err_msg ++ toString x))
      in
        { model | apiResponse = api, msg = msg } ! [Cmd.none]
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
    ChangeParam key value ->
      { model | params = Dict.insert key value model.params } ! [Cmd.none]
    None -> (model, Cmd.none)

--onChange = on "change" Json.map

-- VIEW


(=>) = (,)

view : Model -> Html Msg
view model = div []
  [ viewName model
  , viewRecconectButton model
  , viewMsg model
  , br [] []
  , viewKernelSpecList model
  , viewActiveKernelSpec model
  , br [] []
  , viewLaunchKernelButton model
  , br [] []
  , viewDefault model
  , div [] [text <| toString model]]

viewName : Model -> Html Msg
viewName model =
  input [ style [("background-color" => "red")]
        , name "url"
        , value model.serverUrl
        , onInput ChangeUrl ] []

viewRecconectButton : Model -> Html Msg
viewRecconectButton model =
  button [onClick RefetchUrl] [text "refetch"]

viewMsg : Model -> Html Msg
viewMsg model = span [] [text <| Maybe.withDefault "" model.msg]

viewKernelSpecList : Model -> Html Msg
viewKernelSpecList model =
  select
    [ size 4
    , onInput ChangeType
    ]
    <| List.map (optFor model) (getKernelSpecNameList model)

viewActiveKernelSpec : Model -> Html Msg
viewActiveKernelSpec model = case model.apiResponse of
  Nothing -> div [] []
  Just api ->
    let
      name = Maybe.withDefault api.default model.templateType
      ks = Dict.get name api.kernelSpecs
      (argv, ksDiv) = case ks of
        Nothing -> (["unknown"], div [] [])
        Just ks -> (ks.spec.argv, viewKS ks.spec)
    in
      div []
        [ text <| "argv: " ++ toString argv
        , ksDiv
        ]

viewKS : KernelSpecSpec -> Html Msg
viewKS k =
  case List.member "{parameters_file}" k.argv of
    True -> div [] [text "parameter1: ", input [onInput (ChangeParam "parameter1")] [] ]
    False -> div [] []

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
optFor model s = let
    default = case model.apiResponse of
      Nothing -> "Defaut"
      Just api -> api.default
  in
    option [ value s, selected (Just s == model.templateType || s == default) ] [text s]


api_kernelspec : Model -> String
api_kernelspec model = model.serverUrl ++ "/api/kernelspecs"

getNotebook : Model -> Cmd Msg
getNotebook model =
    let
        request =
            Http.get (Debug.log "Sessions API url: " api_kernelspec model)  decodeKernelSpecAPI
    in
    Http.send FetchKernelSpecAPI request

session_api_url : String
session_api_url = "/api/sessions"


postSession : Model -> String -> Cmd Msg
postSession model name =
  Http.post (model.serverUrl ++ session_api_url) (makeSession model name) decodeSession
    |> Http.send SessionCreated

-- createPostRequest : Model -> String -> Http.Request SessionReq

-- Initially, let's just merge the Json Bodies of a sessionrequst and additional params
makeSession : Model -> String -> Http.Body
makeSession model name =
  Http.jsonBody
    -- <| addKeyValues (E.object ("parameters", toJsonList model.params))
    <| addKeyValues (toJsonList model.params)
    <| encodeSessionReq (makeSessionReq ("session" ++ (toString model.sessionNumber)) name
  )

-- modified from Dogbert's answer at https://stackoverflow.com/questions/50990839/how-to-manipulate-json-encode-value-in-elm#50991106
addKeyValues : List (String, E.Value) -> E.Value -> E.Value
addKeyValues new value =
  case D.decodeValue (D.keyValuePairs D.value) value of
    Ok original ->
      E.object <| List.append new original
    Err _ ->
      value

toJsonList : Dict String String -> List (String, E.Value)
toJsonList d =
  List.map (\(x,y)->(x, E.string y)) (Dict.toList d)

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

decodeKernelSpecAPI : D.Decoder KernelSpecAPI
decodeKernelSpecAPI =
  D.map2 KernelSpecAPI
    (field "default" string)
    (field "kernelspecs" (dict decodeKernelSpec))

decodeKernelSpec : D.Decoder KernelSpec
decodeKernelSpec =
  D.map3 KernelSpec
    (field "name" string)
    (field "spec" decodeKernelSpecSpec)
    (field "resources" (dict string))



decodeKernelSpecSpec : D.Decoder KernelSpecSpec
decodeKernelSpecSpec =
  D.map4 KernelSpecSpec
    (field "argv" (D.list string))
    (field "display_name" string)
    (field "language" string)
    (field "interrupt_mode" string)



-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model = Sub.none
