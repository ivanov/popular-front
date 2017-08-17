module JMessages exposing
  ( Jmsg
  , JmsgContent
  --, JmsgContentData
  --, JmsgContentMetadata
  , JmsgHeader
  , JmsgMetadata
  , JmsgParent_header
  , decodeJmsg
  , encodeJmsg
  )

import Json.Encode
import Json.Decode
import Json.Decode.Pipeline

type alias Jmsg =
    { parent_header : JmsgParent_header
    , msg_type : String
    , msg_id : String
    , content : JmsgContent
    , header : JmsgHeader
    , channel : String
    --, buffers : List ComplexType
    , metadata : JmsgMetadata
    }

type alias JmsgParent_header =
    { date : String
    , msg_id : String
    , version : String
    , msg_type : String
    }

type alias JmsgContent =
    { execution_state : String
    }

type alias JmsgHeader =
    { username : String
    , version : String
    , msg_type : String
    , msg_id : String
    , session : String
    , date : String
    }

type alias JmsgMetadata =
    { 
    }

decodeJmsg : Json.Decode.Decoder Jmsg
decodeJmsg =
    Json.Decode.Pipeline.decode Jmsg
        |> Json.Decode.Pipeline.required "parent_header" (decodeJmsgParent_header)
        |> Json.Decode.Pipeline.required "msg_type" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "msg_id" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "content" (decodeJmsgContent)
        |> Json.Decode.Pipeline.required "header" (decodeJmsgHeader)
        |> Json.Decode.Pipeline.required "channel" (Json.Decode.string)
        -- |> Json.Decode.Pipeline.required "buffers" (Json.Decode.list decodeComplexType)
        |> Json.Decode.Pipeline.required "metadata" (decodeJmsgMetadata)

decodeJmsgParent_header : Json.Decode.Decoder JmsgParent_header
decodeJmsgParent_header =
    Json.Decode.Pipeline.decode JmsgParent_header
        |> Json.Decode.Pipeline.required "date" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "msg_id" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "version" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "msg_type" (Json.Decode.string)

decodeJmsgContent : Json.Decode.Decoder JmsgContent
decodeJmsgContent =
    Json.Decode.Pipeline.decode JmsgContent
        -- this is far from ideal...
        |> Json.Decode.Pipeline.optional "execution_state" (Json.Decode.string) ""

decodeJmsgHeader : Json.Decode.Decoder JmsgHeader
decodeJmsgHeader =
    Json.Decode.Pipeline.decode JmsgHeader
        |> Json.Decode.Pipeline.required "username" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "version" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "msg_type" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "msg_id" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "session" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "date" (Json.Decode.string)

decodeJmsgMetadata : Json.Decode.Decoder JmsgMetadata
decodeJmsgMetadata =
    Json.Decode.Pipeline.decode JmsgMetadata
        --|> Json.Decode.Pipeline.required "" (decode_Unknown)

encodeJmsg : Jmsg -> Json.Encode.Value
encodeJmsg record =
    Json.Encode.object
        [ ("parent_header",  encodeJmsgParent_header <| record.parent_header)
        , ("msg_type",  Json.Encode.string <| record.msg_type)
        , ("msg_id",  Json.Encode.string <| record.msg_id)
        , ("content",  encodeJmsgContent <| record.content)
        , ("header",  encodeJmsgHeader <| record.header)
        , ("channel",  Json.Encode.string <| record.channel)
        , ("metadata",  encodeJmsgMetadata <| record.metadata)
        ]

encodeJmsgParent_header : JmsgParent_header -> Json.Encode.Value
encodeJmsgParent_header record =
    Json.Encode.object
        [ ("date",  Json.Encode.string <| record.date)
        , ("msg_id",  Json.Encode.string <| record.msg_id)
        , ("version",  Json.Encode.string <| record.version)
        , ("msg_type",  Json.Encode.string <| record.msg_type)
        ]

encodeJmsgContent : JmsgContent -> Json.Encode.Value
encodeJmsgContent record =
    Json.Encode.object
        [ ("execution_state",  Json.Encode.string <| record.execution_state)
        ]

encodeJmsgHeader : JmsgHeader -> Json.Encode.Value
encodeJmsgHeader record =
    Json.Encode.object
        [ ("username",  Json.Encode.string <| record.username)
        , ("version",  Json.Encode.string <| record.version)
        , ("msg_type",  Json.Encode.string <| record.msg_type)
        , ("msg_id",  Json.Encode.string <| record.msg_id)
        , ("session",  Json.Encode.string <| record.session)
        , ("date",  Json.Encode.string <| record.date)
        ]

encodeJmsgMetadata : JmsgMetadata -> Json.Encode.Value
encodeJmsgMetadata record =
    Json.Encode.object
        []
