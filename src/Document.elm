module Document exposing
    ( Document
    , DragId(..)
    , DropId(..)
    , HeadingData
    , ImageData
    , LabelData
    , Node
    , NodeId
    , NodeType(..)
    , RowData
    , Template
    , TextData
    , Viewport(..)
    , appendNode
    , applyAlign
    , applyAlignX
    , applyAlignY
    , applyBackground
    , applyBackgroundColor
    , applyBackgroundImage
    , applyBorderColor
    , applyBorderCorner
    , applyBorderLock
    , applyBorderStyle
    , applyBorderWidth
    , applyFontColor
    , applyFontFamily
    , applyFontSize
    , applyFontWeight
    , applyHeight
    , applyHeightMax
    , applyHeightMin
    , applyHeightWith
    , applyLabel
    , applyLabelPosition
    , applyLetterSpacing
    , applyOffset
    , applyPadding
    , applyPaddingLock
    , applyPosition
    , applyShadow
    , applyShadowColor
    , applySpacing
    , applyText
    , applyTextAlign
    , applyWidth
    , applyWidthMax
    , applyWidthMin
    , applyWidthWith
    , applyWordSpacing
    , applyWrapRowItems
    , baseTemplate
    , canDropInto
    , canDropSibling
    , defaultDocument
    , duplicateNode
    , findDeviceInfo
    , fromTemplate
    , fromTemplateAt
    , generateId
    , imageNode
    , insertNode
    , insertNodeAfter
    , insertNodeBefore
    , isContainer
    , isDocumentNode
    , isPageNode
    , isSelected
    , nodeId
    , nodeType
    , removeNode
    , resolveInheritedFontColor
    , resolveInheritedFontFamily
    , resolveInheritedFontSize
    , schemaVersion
    , selectNodeWith
    , selectParentOf
    , viewports
    )

import Css
import Dict exposing (Dict)
import Element exposing (Color, Orientation(..))
import Fonts
import Maybe
import Palette
import Set exposing (Set)
import Style.Background as Background exposing (Background)
import Style.Border as Border exposing (BorderCorner, BorderStyle(..), BorderWidth)
import Style.Font as Font exposing (..)
import Style.Input as Input exposing (LabelPosition(..))
import Style.Layout as Layout exposing (..)
import Style.Shadow as Shadow exposing (Shadow)
import Style.Theme as Theme exposing (Theme)
import Time exposing (Posix)
import Tree as T exposing (Tree)
import Tree.Zipper as Zipper exposing (Zipper)
import UUID exposing (Seeds, UUID)


schemaVersion =
    4


{-| A serialized document.
-}
type alias Document =
    { schemaVersion : Int
    , lastUpdatedOn : Posix
    , root : Tree Node
    , viewport : Viewport
    , collapsedTreeItems : Set String
    }


{-| UUID namespace for built-in library elements.
-}
defaultNamespace =
    UUID.forName "elm-designer.passiomatic.com" UUID.dnsNamespace


type alias NodeId =
    UUID


nodeId : NodeId -> String
nodeId value =
    UUID.toString value


type alias Node =
    { id : NodeId
    , name : String
    , width : Length
    , widthMin : Maybe Int
    , widthMax : Maybe Int
    , height : Length
    , heightMin : Maybe Int
    , heightMax : Maybe Int
    , transformation : Transformation
    , padding : Padding
    , spacing : Spacing
    , fontFamily : Local FontFamily
    , fontColor : Local Color
    , fontSize : Local Int
    , fontWeight : FontWeight
    , letterSpacing : Float
    , wordSpacing : Float
    , textAlignment : TextAlignment
    , borderColor : Color
    , borderStyle : BorderStyle
    , borderWidth : BorderWidth
    , borderCorner : BorderCorner
    , shadow : Shadow
    , background : Background
    , position : Position
    , alignmentX : Alignment
    , alignmentY : Alignment
    , type_ : NodeType
    }


type alias Template =
    Node


type DragId
    = Move Node
    | Insert (Tree Template)


type DropId
    = InsertAfter NodeId
    | InsertBefore NodeId
    | AppendTo NodeId


{-| Just-plain-boring template to build upon.
-}
baseTemplate : Template
baseTemplate =
    { name = ""
    , id = UUID.forName "node-element" defaultNamespace
    , width = Layout.fit
    , widthMin = Nothing
    , widthMax = Nothing
    , height = Layout.fit
    , heightMin = Nothing
    , heightMax = Nothing
    , transformation = Layout.untransformed
    , padding = Layout.padding 0
    , spacing = Layout.spacing 0
    , fontFamily = Inherit
    , fontColor = Inherit
    , fontSize = Inherit
    , fontWeight = Regular
    , letterSpacing = 0
    , wordSpacing = 0
    , textAlignment = TextStart
    , borderColor = Palette.darkCharcoal
    , borderStyle = Solid
    , borderWidth = Border.width 0
    , borderCorner = Border.corner 0
    , shadow = Shadow.none
    , background = Background.None
    , position = Normal
    , alignmentX = None
    , alignmentY = None
    , type_ = PageNode
    }


type NodeType
    = HeadingNode HeadingData
    | ParagraphNode TextData
    | TextNode TextData
    | RowNode RowData
    | ColumnNode
    | TextColumnNode
    | ImageNode ImageData
    | ButtonNode TextData
    | CheckboxNode LabelData
    | TextFieldNode LabelData
    | TextFieldMultilineNode LabelData
    | RadioNode LabelData
    | OptionNode TextData
    | PageNode
    | DocumentNode


nodeType : NodeType -> String
nodeType value =
    case value of
        DocumentNode ->
            "Document"

        HeadingNode heading ->
            "Heading " ++ String.fromInt heading.level

        ParagraphNode _ ->
            "Paragraph"

        PageNode ->
            "Page"

        ColumnNode ->
            "Column"

        RowNode _ ->
            "Row"

        TextColumnNode ->
            "Text Column"

        ImageNode _ ->
            "Image"

        ButtonNode _ ->
            "Button"

        TextFieldNode _ ->
            "Text Field"

        TextFieldMultilineNode _ ->
            "Multiline Field"

        CheckboxNode _ ->
            "Checkbox"

        RadioNode _ ->
            "Radio Selection"

        OptionNode _ ->
            "Radio Option"

        TextNode _ ->
            "Text Snippet"


isPageNode : Node -> Bool
isPageNode node =
    case node.type_ of
        PageNode ->
            True

        _ ->
            False


isDocumentNode : Node -> Bool
isDocumentNode node =
    case node.type_ of
        DocumentNode ->
            True

        _ ->
            False


type alias TextData =
    { text : String
    }


type alias HeadingData =
    { text : String
    , level : Int
    }


type alias LabelData =
    { text : String
    , position : LabelPosition
    }


type alias ImageData =
    { src : String
    , description : String
    }


type alias RowData =
    { wrapped : Bool
    }



-- NODE CONSTRUCTION


generateId : Seeds -> ( NodeId, Seeds )
generateId seeds =
    UUID.step seeds


fromTemplateAt : { a | x : Int, y : Int } -> Tree Node -> Seeds -> ( Seeds, Tree Node )
fromTemplateAt position template seeds =
    T.mapAccumulate
        (\seeds_ template_ ->
            let
                ( uuid, newSeeds ) =
                    generateId seeds_

                newNode =
                    { template_ | id = uuid }
            in
            ( newSeeds, newNode )
        )
        seeds
        template


fromTemplate : Tree Node -> Seeds -> ( Seeds, Tree Node )
fromTemplate template seeds =
    fromTemplateAt { x = 0, y = 0 } template seeds


{-| A startup document with a blank page on it.
-}
defaultDocument : Seeds -> Int -> ( Seeds, Tree Node )
defaultDocument seeds index =
    let
        template =
            T.tree
                { baseTemplate
                    | type_ = DocumentNode
                    , name = "Document " ++ String.fromInt index
                    , width = Layout.fill
                    , height = Layout.fill
                }
                [ -- TODO Pass actual theme value
                  emptyPage Theme.defaultTheme { x = 100, y = 100 }
                ]
    in
    fromTemplate template seeds


emptyPage : Theme -> { a | x : Int, y : Int } -> Tree Node
emptyPage theme position =
    T.singleton
        { baseTemplate
            | type_ = PageNode
            , name = "Page"
            , width = Layout.px 375
            , height = Layout.px 667
            , transformation = Transformation (toFloat position.x) (toFloat position.y) 0 1.0
            , fontFamily = Local theme.textFontFamily
            , fontColor = Local theme.textColor
            , fontSize = Local theme.textSize
            , position = InFront
            , background = Background.Solid theme.backgroundColor
        }


{-| Images require the user to drop them _into_ the app workspace so we bypass the pick-from-library process here.
-}
imageNode : String -> Seeds -> ( Seeds, Tree Node )
imageNode url seeds =
    let
        template =
            T.singleton
                { baseTemplate
                    | type_ = ImageNode { src = url, description = "" }
                    , name = "Image"
                }
    in
    fromTemplate template seeds



-- VIEWPORTS


type Viewport
    = DeviceModel String
    | Custom Int Int Orientation
    | Fluid


deviceInfo =
    Dict.fromList
        [ ( "Galaxy S5", ( 360, 640, Portrait ) )
        , ( "iPhone 5/SE", ( 320, 568, Portrait ) )
        , ( "iPhone 6/7/8", defaultDeviceInfo )
        , ( "iPhone 6/7/8 Plus", ( 414, 736, Portrait ) )
        , ( "iPhone X", ( 375, 812, Portrait ) )
        , ( "iPad", ( 768, 1024, Portrait ) )
        , ( "iPad Pro 12.9\"", ( 1024, 1366, Portrait ) )
        , ( "Surface Duo", ( 540, 720, Portrait ) )
        , ( "MacBook Pro 13\"", ( 1440, 900, Landscape ) )
        ]


{-| Default is iPhone 6/7/8
-}
defaultDeviceInfo =
    ( 375, 667, Portrait )


findDeviceInfo : String -> ( Int, Int, Orientation )
findDeviceInfo name =
    Dict.get name deviceInfo
        |> Maybe.withDefault defaultDeviceInfo


viewports : List Viewport
viewports =
    Fluid :: List.map DeviceModel (Dict.keys deviceInfo)



-- NODE QUERY


{-| Find the node with the given id and if successuful move zipper focus to it.
-}
selectNodeWith : NodeId -> Zipper Node -> Maybe (Zipper Node)
selectNodeWith id zipper =
    Zipper.findFromRoot (\node -> node.id == id) zipper


{-| Find the parent of the node with the given id and if successuful move zipper focus to it.
-}
selectParentOf : NodeId -> Zipper Node -> Maybe (Zipper Node)
selectParentOf id zipper =
    selectNodeWith id zipper
        |> Maybe.andThen Zipper.parent


resolveInheritedFontColor : Color -> Zipper Node -> Color
resolveInheritedFontColor default zipper =
    case resolveInheritedValue .fontColor (Just zipper) of
        Just value ->
            value

        Nothing ->
            default


resolveInheritedFontSize : Int -> Zipper Node -> Int
resolveInheritedFontSize default zipper =
    case resolveInheritedValue .fontSize (Just zipper) of
        Just value ->
            value

        Nothing ->
            default


resolveInheritedFontFamily : FontFamily -> Zipper Node -> FontFamily
resolveInheritedFontFamily default zipper =
    case resolveInheritedValue .fontFamily (Just zipper) of
        Just value ->
            value

        Nothing ->
            default


resolveInheritedValue : (Node -> Local a) -> Maybe (Zipper Node) -> Maybe a
resolveInheritedValue getter maybeZipper =
    case maybeZipper of
        Just zipper ->
            case getter (Zipper.label zipper) of
                Local value ->
                    Just value

                Inherit ->
                    resolveInheritedValue getter (Zipper.parent zipper)

        Nothing ->
            Nothing


isSelected : NodeId -> Zipper Node -> Bool
isSelected id zipper =
    let
        node =
            Zipper.label zipper
    in
    node.id == id


isContainer : Node -> Bool
isContainer node =
    case node.type_ of
        DocumentNode ->
            True

        PageNode ->
            True

        RowNode _ ->
            True

        ColumnNode ->
            True

        TextColumnNode ->
            True

        RadioNode _ ->
            True

        _ ->
            False


canDropInto : Node -> { a | type_ : NodeType } -> Bool
canDropInto container { type_ } =
    case ( container.type_, type_ ) of
        ( RadioNode _, OptionNode _ ) ->
            True

        ( _, OptionNode _ ) ->
            False

        ( PageNode, _ ) ->
            True

        ( DocumentNode, _ ) ->
            True

        ( RowNode _, _ ) ->
            True

        ( ColumnNode, _ ) ->
            True

        ( TextColumnNode, _ ) ->
            True

        ( _, _ ) ->
            False


canDropSibling : Node -> { a | type_ : NodeType } -> Bool
canDropSibling sibling { type_ } =
    case ( sibling.type_, type_ ) of
        -- Only drop radio options next to another option
        ( OptionNode _, OptionNode _ ) ->
            True

        ( OptionNode _, _ ) ->
            False

        ( _, OptionNode _ ) ->
            False

        -- Only drop pages next to another page
        ( PageNode, PageNode ) ->
            True

        ( _, PageNode ) ->
            False

        -- Other scenarios
        ( _, RowNode _ ) ->
            True

        ( _, ColumnNode ) ->
            True

        ( _, TextColumnNode ) ->
            True

        ( _, ImageNode _ ) ->
            True

        ( _, HeadingNode _ ) ->
            True

        ( _, ParagraphNode _ ) ->
            True

        ( _, TextNode _ ) ->
            True

        ( _, ButtonNode _ ) ->
            True

        ( _, CheckboxNode _ ) ->
            True

        ( _, TextFieldNode _ ) ->
            True

        ( _, TextFieldMultilineNode _ ) ->
            True

        ( _, RadioNode _ ) ->
            True

        ( _, _ ) ->
            False



-- NODE EDIT


{-| Traverse the focussed node and generate a new node id for each children.
-}
duplicateNode : Zipper Node -> Seeds -> ( Seeds, Tree Node )
duplicateNode zipper seeds =
    Zipper.tree zipper
        |> T.mapAccumulate
            (\seeds_ node ->
                let
                    ( uuid, newSeeds ) =
                        generateId seeds_
                in
                ( newSeeds, { node | id = uuid } )
            )
            seeds


removeNode : Zipper Node -> Zipper Node
removeNode zipper =
    Zipper.removeTree zipper
        |> Maybe.withDefault (Zipper.root zipper)


{-| A combined append/insert.
-}
insertNode : Tree Node -> Zipper Node -> Zipper Node
insertNode newTree zipper =
    let
        selectedNode =
            Zipper.label zipper
    in
    if isContainer selectedNode then
        -- If the selected node is a container
        --   append the new one as last children...
        appendNode newTree zipper

    else
        -- ...otherwise insert as sibling
        let
            parentZipper =
                Zipper.parent zipper
                    |> Maybe.withDefault (Zipper.root zipper)
        in
        insertNodeAfter selectedNode.id newTree parentZipper


{-| Append the given node as children of focussed node and then move focus to it.
-}
appendNode : Tree Node -> Zipper Node -> Zipper Node
appendNode newTree zipper =
    Zipper.mapTree
        (T.appendChild newTree)
        zipper
        |> Zipper.lastChild
        -- Handle degenerate case
        |> Maybe.withDefault (Zipper.root zipper)


{-| Insert the given node after its sibling, or zipper root as fallback, and move focus to it.
-}
insertNodeAfter : NodeId -> Tree Node -> Zipper Node -> Zipper Node
insertNodeAfter siblingId newTree zipper =
    selectNodeWith siblingId zipper
        |> Maybe.map (Zipper.append newTree)
        |> Maybe.andThen Zipper.nextSibling
        -- Handle degenerate case
        |> Maybe.withDefault (Zipper.root zipper)


{-| Insert the given node before its sibling, or zipper root as fallback, and move focus to it.
-}
insertNodeBefore : NodeId -> Tree Node -> Zipper Node -> Zipper Node
insertNodeBefore siblingId newTree zipper =
    selectNodeWith siblingId zipper
        |> Maybe.map (Zipper.prepend newTree)
        |> Maybe.andThen Zipper.previousSibling
        -- Handle degenerate case
        |> Maybe.withDefault (Zipper.root zipper)



-- NODE PROPERTIES


setText : String -> { a | text : String } -> { a | text : String }
setText value record =
    { record | text = value }


applyLabel : String -> Zipper Node -> Zipper Node
applyLabel value zipper =
    let
        value_ =
            String.trim value
    in
    Zipper.mapLabel
        (\node ->
            case node.type_ of
                TextFieldNode label ->
                    { node | type_ = TextFieldNode (setText value_ label) }

                TextFieldMultilineNode label ->
                    { node | type_ = TextFieldMultilineNode (setText value_ label) }

                ButtonNode button ->
                    { node | type_ = ButtonNode (setText value_ button) }

                CheckboxNode label ->
                    { node | type_ = CheckboxNode (setText value_ label) }

                RadioNode label ->
                    { node | type_ = RadioNode (setText value_ label) }

                OptionNode label ->
                    { node | type_ = OptionNode (setText value_ label) }

                _ ->
                    node
        )
        zipper



-- applyImageSrc : String -> Zipper Node -> Zipper Node
-- applyImageSrc value zipper =
--     Zipper.mapLabel
--         (\node ->
--             case node.type_ of
--                 ImageNode image ->
--                     { node | type_ = ImageNode { image | src = value } }
--                 _ ->
--                     node
--         )
--         zipper


applyText : String -> Zipper Node -> Zipper Node
applyText value zipper =
    Zipper.mapLabel
        (\node ->
            case node.type_ of
                ParagraphNode data ->
                    { node | type_ = ParagraphNode (setText value data) }

                HeadingNode data ->
                    { node | type_ = HeadingNode (setText value data) }

                TextNode data ->
                    { node | type_ = TextNode (setText value data) }

                _ ->
                    node
        )
        zipper


applyTextAlign : TextAlignment -> Zipper Node -> Zipper Node
applyTextAlign value zipper =
    Zipper.mapLabel (Font.setTextAlignment value) zipper


applyWrapRowItems : Bool -> Zipper Node -> Zipper Node
applyWrapRowItems value zipper =
    Zipper.mapLabel (\node -> { node | type_ = RowNode { wrapped = value } }) zipper


applySpacing : (Int -> Spacing -> Spacing) -> String -> Zipper Node -> Zipper Node
applySpacing setter value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 999)
                |> Maybe.withDefault 0
    in
    Zipper.mapLabel (\node -> Layout.setSpacing (setter value_ node.spacing) node) zipper


applyPadding : (Int -> Padding -> Padding) -> String -> Zipper Node -> Zipper Node
applyPadding setter value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 999)
                |> Maybe.withDefault 0
    in
    Zipper.mapLabel (\node -> Layout.setPadding (setter value_ node.padding) node) zipper


applyPaddingLock : Bool -> Zipper Node -> Zipper Node
applyPaddingLock value zipper =
    Zipper.mapLabel (\node -> Layout.setPadding (setLock value node.padding) node) zipper


applyBorderLock : Bool -> Zipper Node -> Zipper Node
applyBorderLock value zipper =
    -- Set both values together
    Zipper.mapLabel
        (\node ->
            node
                |> Border.setWidth (setLock value node.borderWidth)
                |> Border.setCorner (setLock value node.borderCorner)
        )
        zipper


applyAlignX : Alignment -> Zipper Node -> Zipper Node
applyAlignX value zipper =
    Zipper.mapLabel (\node -> { node | alignmentX = value }) zipper


applyAlignY : Alignment -> Zipper Node -> Zipper Node
applyAlignY value zipper =
    Zipper.mapLabel (\node -> { node | alignmentY = value }) zipper


applyAlign : Alignment -> Zipper Node -> Zipper Node
applyAlign value zipper =
    Zipper.mapLabel
        (\node ->
            { node | alignmentX = value, alignmentY = value }
        )
        zipper


applyOffset : (Float -> Transformation -> Transformation) -> String -> Zipper Node -> Zipper Node
applyOffset setter value zipper =
    let
        value_ =
            String.toFloat value
                |> Maybe.map (clamp -999 999)
                |> Maybe.withDefault 0
    in
    Zipper.mapLabel (\node -> setTransformation (setter value_ node.transformation) node) zipper


applyPosition : Position -> Zipper Node -> Zipper Node
applyPosition value zipper =
    Zipper.mapLabel (Layout.setPosition value) zipper


applyWidth : Length -> Zipper Node -> Zipper Node
applyWidth value zipper =
    Zipper.mapLabel (\node -> { node | width = value }) zipper


applyWidthWith : (Maybe Int -> Length -> Length) -> String -> Zipper Node -> Zipper Node
applyWidthWith setter value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 9999)
    in
    Zipper.mapLabel (\node -> { node | width = setter value_ node.width }) zipper


applyWidthMin : String -> Zipper Node -> Zipper Node
applyWidthMin value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 9999)
    in
    Zipper.mapLabel (\node -> { node | widthMin = value_ }) zipper


applyWidthMax : String -> Zipper Node -> Zipper Node
applyWidthMax value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 9999)
    in
    Zipper.mapLabel (\node -> { node | widthMax = value_ }) zipper


applyHeight : Length -> Zipper Node -> Zipper Node
applyHeight value zipper =
    Zipper.mapLabel (\node -> { node | height = value }) zipper


applyHeightWith : (Maybe Int -> Length -> Length) -> String -> Zipper Node -> Zipper Node
applyHeightWith setter value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 9999)
    in
    Zipper.mapLabel (\node -> { node | height = setter value_ node.height }) zipper


applyHeightMin : String -> Zipper Node -> Zipper Node
applyHeightMin value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 9999)
    in
    Zipper.mapLabel (\node -> { node | heightMin = value_ }) zipper


applyHeightMax : String -> Zipper Node -> Zipper Node
applyHeightMax value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 9999)
    in
    Zipper.mapLabel (\node -> { node | heightMax = value_ }) zipper


applyFontSize : String -> Zipper Node -> Zipper Node
applyFontSize value zipper =
    let
        value_ =
            case String.toInt value of
                Just v ->
                    Local (clamp Font.minFontSizeAllowed 999 v)

                Nothing ->
                    Inherit
    in
    Zipper.mapLabel (Font.setSize value_) zipper


applyFontFamily : Local FontFamily -> Zipper Node -> Zipper Node
applyFontFamily value zipper =
    let
        -- First, apply the new family so the inheritance chain is consistent
        newZipper =
            Zipper.mapLabel (Font.setFamily value) zipper
    in
    Zipper.mapLabel
        (\node ->
            let
                resolvedFamily =
                    resolveInheritedFontFamily Fonts.defaultFamily newZipper

                -- While changing family adjust weight to the closest available
                newWeight =
                    Font.findClosestWeight node.fontWeight resolvedFamily.weights
            in
            node
                |> Font.setWeight newWeight
        )
        newZipper


applyLetterSpacing : String -> Zipper Node -> Zipper Node
applyLetterSpacing value zipper =
    let
        value_ =
            String.toFloat value
                |> Maybe.map (clamp -999 999)
                |> Maybe.withDefault 0
    in
    Zipper.mapLabel (Font.setLetterSpacing value_) zipper


applyWordSpacing : String -> Zipper Node -> Zipper Node
applyWordSpacing value zipper =
    let
        value_ =
            String.toFloat value
                |> Maybe.map (clamp -999 999)
                |> Maybe.withDefault 0
    in
    Zipper.mapLabel (Font.setWordSpacing value_) zipper


applyBackgroundColor : String -> Zipper Node -> Zipper Node
applyBackgroundColor value zipper =
    let
        value_ =
            if String.trim value /= "" then
                Background.Solid (Css.stringToColor value)

            else
                Background.None
    in
    Zipper.mapLabel (Background.setBackground value_) zipper


applyBackgroundImage : String -> Zipper Node -> Zipper Node
applyBackgroundImage value zipper =
    let
        value_ =
            if String.trim value /= "" then
                Background.Image value

            else
                Background.None
    in
    Zipper.mapLabel (Background.setBackground value_) zipper


applyBackground : Background -> Zipper Node -> Zipper Node
applyBackground value zipper =
    Zipper.mapLabel (Background.setBackground value) zipper


applyBorderColor : String -> Zipper Node -> Zipper Node
applyBorderColor value zipper =
    let
        value_ =
            Css.stringToColor value
    in
    Zipper.mapLabel (Border.setColor value_) zipper


applyBorderWidth : (Int -> BorderWidth -> BorderWidth) -> String -> Zipper Node -> Zipper Node
applyBorderWidth setter value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 999)
                |> Maybe.withDefault 0
    in
    Zipper.mapLabel (\node -> Border.setWidth (setter value_ node.borderWidth) node) zipper


applyBorderStyle : BorderStyle -> Zipper Node -> Zipper Node
applyBorderStyle value zipper =
    Zipper.mapLabel (Border.setStyle value) zipper


applyBorderCorner : (Int -> BorderCorner -> BorderCorner) -> String -> Zipper Node -> Zipper Node
applyBorderCorner setter value zipper =
    let
        value_ =
            String.toInt value
                |> Maybe.map (clamp 0 999)
                |> Maybe.withDefault 0
    in
    Zipper.mapLabel (\node -> Border.setCorner (setter value_ node.borderCorner) node) zipper


applyFontColor : String -> Zipper Node -> Zipper Node
applyFontColor value zipper =
    let
        value_ =
            Local (Css.stringToColor value)
    in
    Zipper.mapLabel (Font.setColor value_) zipper


applyFontWeight : FontWeight -> Zipper Node -> Zipper Node
applyFontWeight value zipper =
    Zipper.mapLabel (Font.setWeight value) zipper


applyShadow : (Float -> Shadow -> Shadow) -> String -> Zipper Node -> Zipper Node
applyShadow setter value zipper =
    let
        value_ =
            String.toFloat value
                -- TODO handle negative and positive offset values whule clamping 0-positive blur and size
                --|> Maybe.map (clamp 0 999)
                |> Maybe.withDefault 0
    in
    Zipper.mapLabel (\node -> Shadow.setShadow (setter value_ node.shadow) node) zipper


applyShadowColor : String -> Zipper Node -> Zipper Node
applyShadowColor value zipper =
    let
        value_ =
            Css.stringToColor value
    in
    Zipper.mapLabel (\node -> Shadow.setShadow (Shadow.setColor value_ node.shadow) node) zipper


applyLabelPosition : LabelPosition -> Zipper Node -> Zipper Node
applyLabelPosition value zipper =
    Zipper.mapLabel
        (\node ->
            case node.type_ of
                TextFieldNode data ->
                    { node | type_ = TextFieldNode (Input.setLabelPosition value data) }

                TextFieldMultilineNode data ->
                    { node | type_ = TextFieldNode (Input.setLabelPosition value data) }

                CheckboxNode data ->
                    { node | type_ = CheckboxNode (Input.setLabelPosition value data) }

                RadioNode data ->
                    { node | type_ = RadioNode (Input.setLabelPosition value data) }

                _ ->
                    node
        )
        zipper
