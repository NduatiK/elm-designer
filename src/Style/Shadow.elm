module Style.Shadow exposing
    ( Shadow
    , ShadowType(..)
    , none
    , setBlur
    , setColor
    , setOffsetX
    , setOffsetY
    , setShadow
    , setSize
    )

{-| Shadow properties.
-}

import Element exposing (Color)
import Palette


type ShadowType
    = Inner
    | Outer


type alias Shadow =
    { offsetX : Float
    , offsetY : Float
    , size : Float
    , blur : Float
    , color : Color
    , type_ : ShadowType
    }


none =
    Shadow 0 0 0 0 Palette.black Outer


setShadow : Shadow -> { a | shadow : Shadow } -> { a | shadow : Shadow }
setShadow value node =
    { node | shadow = value }


setOffsetX : Float -> Shadow -> Shadow
setOffsetX value record =
    { record | offsetX = value }


setOffsetY : Float -> Shadow -> Shadow
setOffsetY value record =
    { record | offsetY = value }


setBlur : Float -> Shadow -> Shadow
setBlur value record =
    { record | blur = value }


setSize : Float -> Shadow -> Shadow
setSize value record =
    { record | size = value }


setColor : Color -> Shadow -> Shadow
setColor value record =
    { record | color = value }
