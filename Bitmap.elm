module Bitmap exposing (Bitmap, Pixel(..), create, set, toggle, line, circle)

import Array exposing (Array)
import Color


type alias Red =
    Int


type alias Green =
    Int


type alias Blue =
    Int


type alias Alpha =
    Float


type alias Point =
    ( Int, Int )


type Pixel
    = Pixel Red Green Blue Alpha


type alias Bitmap =
    Array (Array Pixel)


create : Int -> Pixel -> Bitmap
create length defaultFill =
    defaultFill
        |> Array.repeat length
        |> Array.repeat length


set : Pixel -> Int -> Int -> Bitmap -> Bitmap
set newFill rowIndex colIndex bitmap =
    let
        set arr =
            Array.set colIndex newFill arr

        newRow =
            Maybe.map set (Array.get rowIndex bitmap)
    in
        case newRow of
            Just row ->
                Array.set rowIndex row bitmap

            Nothing ->
                bitmap


get : Int -> Int -> Bitmap -> Maybe Pixel
get rowIndex colIndex bitmap =
    Maybe.andThen (Array.get rowIndex bitmap) (Array.get colIndex)


toggle : Pixel -> Pixel -> Int -> Int -> Bitmap -> Bitmap
toggle aPixel bPixel rowIndex colIndex bitmap =
    let
        curPixel =
            get rowIndex colIndex bitmap

        alternate pixel =
            if pixel == aPixel then
                bPixel
            else if pixel == bPixel then
                aPixel
            else
                pixel
    in
        case curPixel of
            Just pixel ->
                set (alternate pixel) rowIndex colIndex bitmap

            Nothing ->
                bitmap


closedRange : Int -> Int -> Array Int
closedRange from to =
    let
        -- Add one for closed interval.
        quantity =
            abs (to - from) + 1

        sign =
            if from <= to then
                (+)
            else
                (-)
    in
        Array.initialize quantity identity |> Array.map (sign from)


{-| This function is designed to be used in a fold/reduce call. It should be
    curried with some parameters based on the octant the function is operating
    in.

    The Bresenham line algorithm works by folding/iterating over consecutive
    numbers on an axis. The challenge then is to figure out when a point should
    be plotted on the other axis. The algorithm will accumulate error based
    on how far we stray from the line when we move on our folding axis without
    advancing the other axis. Once this error is greater than half a unit, the
    other axis will be advanced.

    `a` and `b` represent components of a Point. The Bresenham algorithm will
    iterate through consecutive numbers on an axis.
    1 < |dy/dx| < Inf  Fold across the y-axis.
    0 < |dy/dx| <= 1   Fold across the x-axis.
    `a` is the item from the fold function that we are folding across.
    `b` is the item from the accumulator that we are determining.
    For instance, if |dy/dx| <= 1, `a` would be the x-component and `b` would
    be the y-component.

    Due to this, a `plot` function must be provided that calls Bitmap.set with
    the correct component order.

    `slope` is not necessarily dy/dx. It is the number of units to advance per
    unit we're folding across. For instance, if |dy/dx| > 1, we fold across the
    y-axis, and thus want to know how many units of x we should increase per
    unit of the y-axis we fold over. Thus our slope is really the reciprocal,
    dx/dy.

    We may be folding across a decreasing interval or an increasing one, thus we
    need to prove a `delta` argument which provides the next `b` component when
    it advances. Similarly, when the `b` component advances, the error should
    be corrected accordingly, if we're in the first octant and increment our
    y-component with an x-component fold, we should decrement our error
    accumulator. This correction is supplied by the `correction` argument.


    Usage in the first octant with 0 <= dy/dx <= 1 with an increasing
    interval (x1 < x2):

    Fold across the x-axis, such that `b` is our y-component.
    Note that Bitmap.set takes rowIndex before colIndex (y before x)
    bresenhamLinePlot (dy/dx) 1 -1 (\a b -> set pixel b a bitmap)
-}
bresenhamLinePlot : Float -> Int -> Float -> (Int -> Int -> Bitmap -> Bitmap) -> Int -> ( Bitmap, Float, Int ) -> ( Bitmap, Float, Int )
bresenhamLinePlot slope delta correction plot a ( bitmap, error, b ) =
    let
        nextBitmap =
            plot a b bitmap

        shouldAdvance =
            abs (error + slope) > 0.5

        ( nextError, nextB ) =
            if shouldAdvance then
                ( error + slope + correction, b + delta )
            else
                ( error + slope, b )
    in
        ( nextBitmap, nextError, nextB )


line : Pixel -> Point -> Point -> Bitmap -> Bitmap
line pixel origin endpoint bitmap =
    let
        ( x1, y1 ) =
            origin

        ( x2, y2 ) =
            endpoint

        dx =
            x2 - x1

        dy =
            y2 - y1

        m =
            (toFloat dy) / (toFloat dx)

        -- We cannot use the traditional slope (y per x) if we plot through
        -- ys instead of xs. We would need to use the reciprocal slope, the
        -- units x per unit y.
        rM =
            (toFloat dx) / (toFloat dy)

        foldingAcrossX a b bitmap =
            set pixel b a bitmap

        foldingAcrossY a b bitmap =
            set pixel a b bitmap

        ( plotFunc, interval, start ) =
            if 0 <= m && m <= 1 && x1 < x2 then
                -- First octant.
                ( bresenhamLinePlot m 1 -1 foldingAcrossX
                , closedRange x1 x2
                , y1
                )
            else if 1 < m && y1 < y2 then
                -- Second octant.
                ( bresenhamLinePlot rM 1 -1 foldingAcrossY
                , closedRange y1 y2
                , x1
                )
            else if -1 > m && y1 < y2 then
                -- Third octant.
                ( bresenhamLinePlot rM 1 1 foldingAcrossY
                , closedRange y2 y1
                , x2
                )
            else if 0 > m && m >= -1 && x2 < x1 then
                -- Fourth octant.
                ( bresenhamLinePlot m -1 1 foldingAcrossX
                , closedRange x2 x1
                , y2
                )
            else if 0 < m && m <= 1 && x2 < x1 then
                -- Fifth octant.
                ( bresenhamLinePlot m 1 -1 foldingAcrossX
                , closedRange x2 x1
                , y2
                )
            else if 1 < m && y2 < y1 then
                -- Sixth octant.
                ( bresenhamLinePlot rM 1 -1 foldingAcrossY
                , closedRange y2 y1
                , x2
                )
            else if -1 > m && y2 < y1 then
                -- Seventh octant.
                ( bresenhamLinePlot rM 1 1 foldingAcrossY
                , closedRange y1 y2
                , x1
                )
            else if 0 > m && m >= -1 && x1 < x2 then
                -- Eighth octant.
                ( bresenhamLinePlot m -1 1 foldingAcrossX
                , closedRange x1 x2
                , y1
                )
            else
                ( bresenhamLinePlot m 1 -1 foldingAcrossX
                , closedRange x1 x2
                , y1
                )

        ( newBitmap, _, _ ) =
            Array.foldl plotFunc ( bitmap, 0, start ) interval
    in
        newBitmap


plotSymmetricalOctants : (Int -> Int -> Bitmap -> Bitmap) -> Bitmap -> Int -> Int -> Bitmap
plotSymmetricalOctants plot bitmap x y =
    bitmap
        |> plot x y
        |> plot -x y
        |> plot -x -y
        |> plot x -y
        |> plot y x
        |> plot -y x
        |> plot -y -x
        |> plot y -x


bresenhamCirclePlot : (Int -> Int -> Bitmap -> Bitmap) -> Int -> Int -> ( Bitmap, Int, Int, Int, Int ) -> ( Bitmap, Int, Int, Int, Int )
bresenhamCirclePlot plot radius y ( bitmap, x, xChange, yChange, radiusError ) =
    let
        nextBitmap =
            plotSymmetricalOctants plot bitmap x y

        -- We are trying to minimize the deviance/error from the true equation of the
        -- circle, just as with the line plot algorithm.
        -- See http://web.engr.oregonstate.edu/~sllu/bcircle.pdf for proof.
        --
        -- Essentially, we are folding over the y-coordinate interval, thus,
        -- our y-coordinate value is always going to increment. We need to
        -- determine whether we should decrement the x-coordinate value or not.
        -- We can compare Error(x[i] - 1, y[i] + 1) and Error(x[i], y[i] + 1).
        -- We will return the next x-coordinate value based on which call
        -- returns the smallest value, thus, the least error. Letting these
        -- functions be an inequality and reducing it algebraically reduces the
        -- predicate down to this.
        shouldDecrementX =
            2 * (radiusError + yChange) + xChange > 0

        nextYChange =
            yChange + 2

        ( nextX, nextXChange, nextRadiusError ) =
            if shouldDecrementX then
                ( x - 1, xChange + 2, radiusError + yChange + xChange )
            else
                ( x, xChange, radiusError + yChange )
    in
        ( nextBitmap, nextX, nextXChange, nextYChange, nextRadiusError )


circle : Pixel -> Int -> Int -> Int -> Bitmap -> Bitmap
circle pixel cX cY radius bitmap =
    let
        plot x y =
            set pixel (y + cY) (x + cX)

        initValues =
            ( bitmap, radius, 1 - 2 * radius, 1, 0 )

        interval =
            closedRange 0 radius

        ( nextBitmap, _, _, _, _ ) =
            Array.foldl (bresenhamCirclePlot plot radius) initValues interval
    in
        nextBitmap
