module JSessions exposing
  ( Session
  , decodeSession
  , decodeSessions
  , encodeSession
  , encodeSessionReq
  , makeSessionReq
  , sampleSessions
  )

-- started as http://eeue56.github.io/json-to-elm/ conversion from
-- /api/sessions endpoint

import Json.Encode
import Json.Decode exposing (field, list, decodeString, maybe, oneOf)

type alias Session =
    { kernel : SessionKernel
    , notebook : Maybe SessionNotebook
    , id : String
    , path : String
    }

type alias SessionKernel =
    { id : String
    , name : String
    }

type alias SessionRequest =
  { path: String
  , type_: String
  , name: String
  , kernel:
    { id: Json.Encode.Value
     , name: String
    }
  }

makeSessionReq : String -> String -> SessionRequest
makeSessionReq path name =
  { path=path
  , type_= "notebook"
  , name= ""
  , kernel=
    { id= Json.Encode.null
    , name= name
    }
  }

type alias SessionNotebook =
    { path : String
    }

decodeSession : Json.Decode.Decoder Session
decodeSession =
    Json.Decode.map4 Session
        (field "kernel" decodeSessionKernel)
        (maybe (field "notebook"decodeSessionNotebook))
        (field "id" Json.Decode.string)
        (field "path" Json.Decode.string)

decodeSessionKernel : Json.Decode.Decoder SessionKernel
decodeSessionKernel =
    Json.Decode.map2 SessionKernel
        (field "id" Json.Decode.string)
        (field "name" Json.Decode.string)

decodeSessionNotebook : Json.Decode.Decoder SessionNotebook
decodeSessionNotebook =
    Json.Decode.map SessionNotebook
        (field "path" Json.Decode.string)

encodeSession : Session -> Json.Encode.Value
encodeSession record =
    case record.notebook of
      Nothing ->
        Json.Encode.object
            [ ("kernel",  encodeSessionKernel <| record.kernel)
            , ("id",  Json.Encode.string <| record.id)
            , ("path",  Json.Encode.string <| record.path)
            ]
      Just notebook ->
        Json.Encode.object
            [ ("kernel",  encodeSessionKernel <| record.kernel)
            , ("notebook",  encodeSessionNotebook <| notebook)
            , ("id",  Json.Encode.string <| record.id)
            , ("path",  Json.Encode.string <| record.path)
            ]

encodeSessionKernel : SessionKernel -> Json.Encode.Value
encodeSessionKernel record =
    Json.Encode.object
        [ ("id",  Json.Encode.string <| record.id)
        , ("name",  Json.Encode.string <| record.name)
        ]

encodeSessionNotebook : SessionNotebook -> Json.Encode.Value
encodeSessionNotebook record =
    Json.Encode.object
        [ ("path",  Json.Encode.string <| record.path)
        ]

encodeSessionReq : SessionRequest -> Json.Encode.Value
encodeSessionReq record =
    Json.Encode.object
        [ ( "path",  Json.Encode.string record.path)
        , ( "type",  Json.Encode.string record.type_)
        , ( "name",  Json.Encode.string record.name)
        , ( "kernel",  (Json.Encode.object
            [ ("id", record.kernel.id)
            , ("name", Json.Encode.string record.kernel.name)
            ])
          )
        ]


sampleSessions_string = """[{"kernel": {"id": "6c926cc6-05d5-4e47-b1b8-cf51819c711d",
"name": "pomegranate"}, "notebook": {"path": "Demo notebook.ipynb"}, "id":
"0a9c4329-4107-4200-b4e6-69e9b5d59a4d"}, {"kernel": {"id":
"92c35da9-b880-4637-a655-1ef9ca75ffef", "name": "pomegranate"}, "notebook":
{"path": "Orly - JupyterCon.ipynb"}, "id":
"767c5358-824a-474b-88c6-a478930df66a"}]"""

sampleSessions = case decodeString (list decodeSession) sampleSessions_string of
  Ok x -> x
  Err y -> []

decodeSessions =  list decodeSession
