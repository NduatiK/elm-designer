port module Ports exposing
    ( copyToClipboard
    , loadDocument
    , onDocumentLoad
    , saveDocument
    , selectText
    , setDragImage
    , setFontLinks
    , showNotification
    )

import Json.Decode exposing (Value)
import Model exposing (..)



-- PORTS OUT


port saveDocument : String -> Cmd msg


port loadDocument : () -> Cmd msg


port copyToClipboard : String -> Cmd msg


port selectText : String -> Cmd msg


port setFontLinks : List String -> Cmd msg


port setDragImage : { event : Value, width : Maybe Int, height : Maybe Int } -> Cmd msg


port showNotification :
    { title : String
    , message : String
    }
    -> Cmd msg



-- PORTS IN


port onDocumentLoad : (String -> msg) -> Sub msg
