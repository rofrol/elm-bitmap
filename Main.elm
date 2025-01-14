module Main exposing (..)

import Array
import Bitmap
import Debug exposing (log)
import GraphicSVG exposing (..)
import GraphicSVG.App exposing (..)
import List


drawPixel rowIndex colIndex pixel =
    let
        (Bitmap.Pixel r g b a) =
            pixel

        x =
            toFloat colIndex * cellSize

        y =
            toFloat rowIndex * cellSize
    in
    square cellSize
        |> filled (rgba (toFloat r) (toFloat g) (toFloat b) a)
        |> move ( x, y )
        |> notifyTap (Toggle colIndex rowIndex)


drawBitmap bitmap =
    let
        drawRow index row =
            Array.indexedMap (drawPixel index) row
                |> Array.toList
                |> group
    in
    Array.indexedMap drawRow bitmap
        |> Array.toList
        |> group


white =
    Bitmap.Pixel 200 255 255 1


black =
    Bitmap.Pixel 0 0 0 1


type Message
    = GameTick Float GetKeyState
    | Toggle Int Int


cellSize =
    6


main =
    gameApp GameTick
        { model = init
        , view = view
        , update = update
        , title = "elm-bitmap"
        }


init =
    { t = 0
    , bitmap =
        Bitmap.create 64 white
            |> Bitmap.circle black ( 43, 40 ) 3
            |> Bitmap.circle black ( 20, 40 ) 3
            |> Bitmap.circle black ( 31, 31 ) 25
            |> Bitmap.curve black [ ( 15, 25 ), ( 31.5, 10 ), ( 48, 25 ) ]
    }


view model =
    let
        center =
            move ( cellSize * -32, cellSize * -32 )
    in
    collage 600
        600
        [ drawBitmap model.bitmap |> center
        ]


update message model =
    case message of
        Toggle row col ->
            { model
                | bitmap = Bitmap.toggle black white row col model.bitmap
            }

        _ ->
            model
