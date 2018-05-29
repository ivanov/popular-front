module JMessages
    exposing
        ( Jmsg (..)
        , Jmsg_
        --, UnknownMessage
        , JmsgContent
        , JmsgContentData
          --, JmsgContentMetadata
        , JmsgHeader
        , JmsgMetadata
        , JmsgParent_header
        , brokenJmsg
        , decodeJmsg
        , encodeJmsg
        )

import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (optional, required)
import Json.Encode


-- Yes, this is rather messy, it's a cleanup version of autogenerated json2elm
-- output done via http://eeue56.github.io/json-to-elm/


--type alias UnknownMessage = String

type alias Jmsg_ =
    { parent_header : JmsgParent_header

    --, msg_type : String
    -- , msg_id : String
    , content : JmsgContent
    , header : JmsgHeader
    , channel : String

    --, buffers : List ComplexType
    , metadata : JmsgMetadata
    }


type Jmsg
  = Known Jmsg_
  | UnknownMessage


type alias JmsgParent_header =
    { date : String
    , msg_id : String

    --, version : String
    , msg_type : String
    }


type alias JmsgContent =
    { execution_state : Maybe String
    , data : Maybe JmsgContentData
    }



-- TODO - we should have separate message types, and use oneOf decoders with
-- them to figure out which message we actually have...


type alias JmsgContentData =
    { text_html : Maybe String
    , text_plain : Maybe String
    , code : Maybe String
    , execution_count : Maybe Int
    }


type alias JmsgHeader =
    { username : String

    --, version : String
    , msg_type : String
    , msg_id : String
    , session : String
    , date : String
    }


type alias JmsgMetadata =
    {}


decodeJmsg_ : Json.Decode.Decoder Jmsg_
decodeJmsg_ =
    Json.Decode.Pipeline.decode Jmsg_
        |> required "parent_header" decodeJmsgParent_header
        -- |> required "msg_type" (Json.Decode.string)
        -- |> required "msg_id" (Json.Decode.string)
        |> optional "content" decodeJmsgContent (JmsgContent Nothing Nothing)
        |> required "header" decodeJmsgHeader
        |> optional "channel" Json.Decode.string "shell"
        -- |> required "buffers" (Json.Decode.list decodeComplexType)
        |> optional "metadata" decodeJmsgMetadata {}

decodeUnknownJmsg : Json.Decode.Decoder Jmsg
decodeUnknownJmsg = Json.Decode.Pipeline.decode UnknownMessage

decodeJmsg : Json.Decode.Decoder Jmsg
decodeJmsg =
   oneOf [ map Known decodeJmsg_, decodeUnknownJmsg ]

decodeJmsgParent_header : Json.Decode.Decoder JmsgParent_header
decodeJmsgParent_header =
    Json.Decode.Pipeline.decode JmsgParent_header
        |> optional "date" Json.Decode.string "SOMETIME"
        --|> optional "msg_id" Json.Decode.string "<blank_msg_id>"
        |> optional "msg_id" Json.Decode.string ""
        --|> required "version" (Json.Decode.string)
        |> optional "msg_type" Json.Decode.string "some_msg_type"


decodeJmsgContent : Json.Decode.Decoder JmsgContent
decodeJmsgContent =
    Json.Decode.Pipeline.decode JmsgContent
        -- this is far from ideal...
        |> optional "execution_state" (maybe string) Nothing
        |> optional "data" (maybe decodeJmsgContentData) Nothing


decodeJmsgContentData : Json.Decode.Decoder JmsgContentData
decodeJmsgContentData =
    Json.Decode.Pipeline.decode JmsgContentData
        |> optional "text/html" (maybe string) Nothing
        |> optional "text/plain" (maybe string) Nothing
        |> optional "code" (maybe string) Nothing
        |> optional "execution_count" (maybe int) Nothing


decodeJmsgHeader : Json.Decode.Decoder JmsgHeader
decodeJmsgHeader =
    Json.Decode.Pipeline.decode JmsgHeader
        |> required "username" Json.Decode.string
        --|> required "version" (Json.Decode.string)
        |> required "msg_type" Json.Decode.string
        |> required "msg_id" Json.Decode.string
        |> required "session" Json.Decode.string
        |> optional "date" Json.Decode.string "NODATE"


decodeJmsgMetadata : Json.Decode.Decoder JmsgMetadata
decodeJmsgMetadata =
    Json.Decode.Pipeline.decode JmsgMetadata



--|> required "" (decode_Unknown)

encodeJmsg : Jmsg -> Json.Encode.Value
encodeJmsg record = case record of
  Known msg -> encodeJmsg_ msg
  UnknownMessage -> Json.Encode.string "unknown_message"

encodeJmsg_ : Jmsg_ -> Json.Encode.Value
encodeJmsg_ record =
    Json.Encode.object
        [ ( "parent_header", encodeJmsgParent_header <| record.parent_header )

        --, ("msg_type",  Json.Encode.string <| record.msg_type)
        --, ("msg_id",  Json.Encode.string <| record.msg_id)
        , ( "content", encodeJmsgContent <| record.content )
        , ( "header", encodeJmsgHeader <| record.header )
        , ( "channel", Json.Encode.string <| record.channel )
        , ( "metadata", encodeJmsgMetadata <| record.metadata )
        ]


encodeJmsgParent_header : JmsgParent_header -> Json.Encode.Value
encodeJmsgParent_header record =
    Json.Encode.object
        [ ( "date", Json.Encode.string <| record.date )
        , ( "msg_id", Json.Encode.string <| record.msg_id )

        --, ("version",  Json.Encode.string <| record.version)
        , ( "msg_type", Json.Encode.string <| record.msg_type )
        ]


encodeJmsgContent : JmsgContent -> Json.Encode.Value
encodeJmsgContent record =
    Json.Encode.object
        [--  ("execution_state",  (Json.Encode.maybe Json.Encode.string) <| record.execution_state)
        ]


encodeJmsgHeader : JmsgHeader -> Json.Encode.Value
encodeJmsgHeader record =
    Json.Encode.object
        [ ( "username", Json.Encode.string <| record.username )

        --, ("version",  Json.Encode.string <| record.version)
        , ( "msg_type", Json.Encode.string <| record.msg_type )
        , ( "msg_id", Json.Encode.string <| record.msg_id )
        , ( "session", Json.Encode.string <| record.session )
        , ( "date", Json.Encode.string <| record.date )
        ]


encodeJmsgMetadata : JmsgMetadata -> Json.Encode.Value
encodeJmsgMetadata record =
    Json.Encode.object
        []


brokenJmsg : String -> Jmsg_
brokenJmsg s =
    Jmsg_
        { date = "broken", msg_id = "broken", msg_type = "hi" }
        -- parentHeader
        { execution_state = Just s, data = Nothing }
        { username = "luser", msg_type = "broken", msg_id = "broken", date = "broken", session = "broken" }
        "broken"
        {}
