import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, on)
import Json.Encode exposing (encode)
import Http
import Json.Decode exposing (field, int, oneOf, string, dict)
import Dict exposing (Dict)
import Task

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
  }

init : ( Model, Cmd Msg )
init = (
  { fullName = Nothing
  , templateType = List.head appTypes
  , apiResponse = Nothing
  }, send (ChangeType "default"))

send : Msg -> Cmd Msg
send msg = Task.succeed msg
  |> Task.perform identity

-- UPDATE
type Msg
    = None
    | ChangeName String
    | ChangeType String
    | NewKernelSpec (Result Http.Error KernelSpecAPI)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let x = Debug.log (toString model) "update..." in
  case msg of
    ChangeName s -> {model | fullName = Just s} ! [Cmd.none]
    ChangeType s -> {model | templateType = Just s} ! [getNotebook model]
    NewKernelSpec result ->
    let
      notebook = case result of
        Ok nb -> Just nb
        Err x -> Debug.log ("couldn't load nb" ++ toString x) Nothing
    in
      {model | apiResponse = notebook } ! [Cmd.none]
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
    Http.send NewKernelSpec request


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
