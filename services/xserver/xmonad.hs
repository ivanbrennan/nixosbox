{-# LANGUAGE NamedFieldPuns #-}
{-# OPTIONS_GHC -O2 -Wall -Werror #-}

{- base -}
import Control.Arrow (second)
import Control.Monad (when, (>=>))
import Data.Bits ((.|.))
import Data.List (intercalate, isInfixOf)
import Data.Monoid (All)
import System.Directory (getHomeDirectory)
import System.Exit (exitSuccess)
import System.FilePath ((</>))
import System.IO (Handle)

{- containers -}
import Data.Map (Map)
import qualified Data.Map as M

{- data-default -}
import Data.Default (def)

{- process -}
import System.Process.Internals (translate)

{- X11 -}
import Graphics.X11
  ( Button, KeyMask, KeySym, Window, button1, controlMask, mod1Mask, mod4Mask,
    noModMask, shiftMask, xK_1, xK_9, xK_Alt_L, xK_Alt_R, xK_Print, xK_Tab, xK_a,
    xK_c, xK_comma, xK_d, xK_e, xK_g, xK_h, xK_i, xK_j, xK_k, xK_l, xK_m, xK_n,
    xK_o, xK_p, xK_period, xK_q, xK_r, xK_semicolon, xK_slash, xK_space, xK_t,
    xK_v, xK_w, xK_x, xK_y, xK_z,
  )
import Graphics.X11.ExtraTypes
  ( xF86XK_AudioLowerVolume, xF86XK_AudioMute, xF86XK_AudioRaiseVolume,
    xF86XK_Copy, xF86XK_MonBrightnessDown, xF86XK_MonBrightnessUp, xF86XK_Paste,
  )
import Graphics.X11.Xlib.Extras (Event)

{- xmonad -}
import XMonad
  ( ChangeLayout (FirstLayout, NextLayout), Choose, Full (Full),
    IncMasterN (IncMasterN), Layout, ManageHook, Mirror (Mirror), MonadIO, Query,
    Resize (Expand, Shrink), ScreenId (S), WindowSet, WindowSpace, WorkspaceId,
    X, XConf, XConfig (XConfig), appName, className, clickJustFocuses,
    composeAll, config, description, doFloat, doIgnore, focus,
    focusedBorderColor, handleEventHook, io, keys, kill, layoutHook, local,
    logHook, manageHook, modMask, mouseBindings, mouseMoveWindow,
    normalBorderColor, refresh, screenWorkspace, sendMessage, spawn, startupHook,
    terminal, trace, whenJust, windows, withFocused, withWindowSet, workspaces,
    xmonad, (=?), (|||),
  )
import qualified XMonad.StackSet as W

{- xmonad-contrib -}
import XMonad.Actions.CycleWS
  ( Direction1D (Next, Prev), WSType (WSIs, NonEmptyWS), moveTo,
  )
import XMonad.Actions.DynamicProjects (dynamicProjects, changeProjectDirPrompt')
import XMonad.Actions.FlexibleResize (mouseResizeEdgeWindow)
import XMonad.Actions.PerWindowKeys (bindFirst)
import XMonad.Actions.RotateSome (surfaceNext, surfacePrev)
import XMonad.Actions.RotSlaves (rotAllDown, rotAllUp, rotSlavesDown, rotSlavesUp)
import XMonad.Actions.Submap (submap)
import XMonad.Actions.WindowBringer (gotoMenuArgs)
import XMonad.Actions.WorkspaceNames (renameWorkspace, workspaceNamesPP)
import XMonad.Hooks.DebugStack (debugStackString)
import XMonad.Hooks.DynamicBars
  ( dynStatusBarEventHook, dynStatusBarStartup, multiPPFormat,
  )
import XMonad.Hooks.DynamicLog
  ( PP, dynamicLogString, pad, ppCurrent, ppHidden, ppLayout, ppSep, ppTitle,
    ppWsSep, wrap, xmobarColor, xmobarPP,
  )
import XMonad.Hooks.EwmhDesktops (ewmh, fullscreenEventHook)
import XMonad.Hooks.InsertPosition
  ( Focus (Newer), Position (Above), insertPosition,
  )
import XMonad.Hooks.ManageDebug (debugManageHookOn)
import XMonad.Hooks.ManageDocks (ToggleStruts (ToggleStruts), avoidStruts, docks)
import XMonad.Hooks.ManageHelpers
  ( composeOne, doCenterFloat, doRectFloat, isDialog, (-?>),
  )
import XMonad.Hooks.RefocusLast
  ( RefocusLastLayoutHook, isFloat, refocusLastLayoutHook, refocusLastWhen,
    shiftRLWhen, swapWithLast, toggleFocus,
  )
import XMonad.Layout.BoringWindows
  ( BoringWindows, boringAuto, focusDown, focusUp, siftDown, siftUp,
  )
import XMonad.Layout.IndependentScreens
  ( PhysicalWorkspace, VirtualWorkspace, countScreens, marshall, marshallPP,
    unmarshallS, withScreens, workspaces',
  )
import XMonad.Layout.LayoutModifier (ModifiedLayout)
import XMonad.Layout.LimitWindows
  ( Selection, limitSelect, decreaseLimit, increaseLimit,
  )
import XMonad.Layout.NoBorders (SmartBorder, smartBorders)
import XMonad.Layout.Renamed (Rename (Append, Prepend), renamed)
import XMonad.Layout.ResizableTile
  ( ResizableTall (ResizableTall), MirrorResize (MirrorShrink, MirrorExpand),
  )
import XMonad.Layout.StateFull (FocusTracking, focusTracking)
import XMonad.Layout.ToggleLayouts
  ( ToggleLayout (ToggleLayout), ToggleLayouts, toggleLayouts,
  )
import XMonad.Prompt
  ( ComplCaseSensitivity (ComplCaseSensitive), XPConfig, XPPosition (Top),
    alwaysHighlight, bgColor, bgHLight, defaultXPKeymap, fgColor, fgHLight, font,
    height, moveHistory, position, promptBorderWidth, promptKeymap,
  )
import XMonad.Prompt.AppendFile (appendFilePrompt')
import XMonad.Prompt.ConfirmPrompt (confirmPrompt)
import XMonad.Prompt.Man (manPrompt)
import XMonad.Prompt.RunOrRaise (runOrRaisePrompt)
import XMonad.Prompt.Workspace (workspacePrompt)
import XMonad.Prompt.XMonad (xmonadPromptC)
import XMonad.Util.Loggers (date)
import XMonad.Util.NamedScratchpad
  ( NamedScratchpad (NS), namedScratchpadAction,
    namedScratchpadFilterOutWorkspace, namedScratchpadFilterOutWorkspacePP,
    namedScratchpadManageHook,
  )
import qualified XMonad.Util.NamedScratchpad as NS
import XMonad.Util.Paste (sendKey)
import XMonad.Util.Run (spawnPipe)


main :: IO ()
main =
  xmonad . xconfig =<< countScreens
  where
    xconfig nScreens =
      docks $
      debugManageHookOn "M1-M4-v" $
      dynamicProjects [] $
      ewmh $
        def
          { layoutHook         = avoidStruts layoutHook',
            terminal           = "alacritty",
            clickJustFocuses   = False,
            normalBorderColor  = grey1,
            focusedBorderColor = grey2,
            keys               = keys',
            mouseBindings      = mouseBindings',
            manageHook         = manageHook',
            handleEventHook    = eventHook,
            logHook            = logHook',
            startupHook        = startupHook',
            workspaces         = withScreens nScreens (workspaces def)
          }

-- https://github.com/xmonad/X11/blob/6e5ef8019a0cc49e18410a335dbdeea87b7c4aac/Graphics/X11/Types.hsc
-- https://stackoverflow.com/questions/6605399/how-can-i-set-an-action-to-occur-on-a-key-release-in-xmonad

keys' :: XConfig Layout -> Map (KeyMask, KeySym) (X ())
keys' conf@(XConfig {modMask}) =
  M.fromList $
    [ -- layout algorithms
      ( (mod4Mask, xK_space),
        fullToggleOff >> sendMessage NextLayout
      ),
      ( (mod4Mask .|. shiftMask, xK_space),
        fullToggleOff >> sendMessage FirstLayout
      ),
      ( (modMask, xK_space),
        sendMessage ToggleLayout
      ),
      ( (mod4Mask, xK_slash),
        sendMessage ToggleStruts
      ),
      -- workspaces
      ( (modMask, xK_period),
        moveTo Next cycledWorkspace
      ),
      ( (modMask, xK_comma),
        moveTo Prev cycledWorkspace
      ),
      ( (modMask, xK_l),
        toggleRecentWS
      ),
      ( (mod4Mask, xK_Tab),
        moveTo Next NonEmptyWS
      ),
      ( (modMask .|. shiftMask, xK_semicolon),
        changeWorkspaceDir
      ),
      -- focus
      ( (modMask, xK_j),
        do
          t <- isFullToggleOn
          if t then windows W.focusDown else focusDown
      ),
      ( (modMask, xK_k),
        do
          t <- isFullToggleOn
          if t then windows W.focusUp else focusUp
      ),
      ( (modMask, xK_m),
        windows W.focusMaster
      ),
      ( (modMask, xK_semicolon),
        toggleFocus
      ),
      ( (mod4Mask, xK_semicolon),
        swapWithLast
      ),
      -- rotation
      ( (modMask .|. controlMask, xK_k),
        rotSlavesDown
      ),
      ( (modMask .|. controlMask, xK_j),
        rotSlavesUp
      ),
      ( (modMask .|. controlMask, xK_i),
        rotAllDown
      ),
      ( (modMask .|. controlMask, xK_o),
        rotAllUp
      ),
      ( (modMask .|. controlMask, xK_n),
        surfaceNext
      ),
      ( (modMask .|. controlMask, xK_p),
        surfacePrev
      ),
      ( (modMask .|. controlMask, xK_comma),
        increaseLimit
      ),
      ( (modMask .|. controlMask, xK_period),
        decreaseLimit
      ),
      ( (mod4Mask .|. controlMask, xK_comma),
        sendMessage (IncMasterN 1)
      ),
      ( (mod4Mask .|. controlMask, xK_period),
        sendMessage (IncMasterN (-1))
      ),
      -- swap
      ( (modMask .|. shiftMask, xK_m),
        windows W.swapMaster
      ),
      ( (modMask .|. shiftMask, xK_j),
        siftDown
      ),
      ( (modMask .|. shiftMask, xK_k),
        siftUp
      ),
      -- resize
      ( (mod4Mask, xK_h),
        sendMessage Shrink
      ),
      ( (mod4Mask, xK_l),
        sendMessage Expand
      ),
      ( (mod4Mask, xK_j),
        sendMessage MirrorShrink
      ),
      ( (mod4Mask, xK_k),
        sendMessage MirrorExpand
      ),
      -- refresh
      ( (mod4Mask .|. shiftMask, xK_r),
        refresh
      ),
      -- tile
      ( (mod4Mask, xK_t),
        withFocused (windows . W.sink)
      ),
      -- quit or restart
      ( (mod4Mask, xK_q),
        spawn "xmonad --recompile && xmonad --restart"
      ),
      ( (mod4Mask .|. modMask, xK_q),
        spawn $
          intercalate
            ";"
            [ "ln -s /dev/null ~/.xmonad/xmonad.state || true",
              "xmonad --recompile && xmonad --restart"
            ]
      ),
      ( (mod4Mask .|. shiftMask, xK_q),
        confirmPrompt xPConfig "exit" (io exitSuccess)
      ),
      -- launch/kill
      ( (modMask, xK_i),
        spawn (terminal conf)
      ),
      ( (controlMask, xK_space),
        spawn dmenu
      ),
      ( (controlMask .|. shiftMask, xK_space),
        namedScratchpadAction scratchpads (NS.name scratchTerminal)
      ),
      ( (mod4Mask .|. modMask, xK_y),
        debugStackString
          >>= trace . unlines . uncurry (++) . second reverse . splitAt 1 . lines
      ),
      ( (noModMask, xK_Print),
        spawn "screenshot"
      ),
      ( (controlMask, xK_Print),
        spawn "screenshot -c"
      ),
      ( (shiftMask, xK_Print),
        spawn "screenshot -a"
      ),
      ( (controlMask .|. shiftMask, xK_Print),
        spawn "screenshot -a -c"
      ),
      ( (mod4Mask .|. shiftMask, xK_d),
        kill
      ),
      ( (modMask .|. shiftMask, xK_space),
        spawn $ unwords ("passmenu" : dmenuArgs)
      ),
      -- volume
      ( (noModMask, xF86XK_AudioRaiseVolume),
        spawn "pactl set-sink-mute @DEFAULT_SINK@ 0 && pactl set-sink-volume @DEFAULT_SINK@ +2%"
      ),
      ( (noModMask, xF86XK_AudioLowerVolume),
        spawn "pactl set-sink-volume @DEFAULT_SINK@ -2%"
      ),
      ( (noModMask, xF86XK_AudioMute),
        spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle"
      ),
      ( (mod4Mask, xF86XK_AudioMute),
        spawn "pactl set-source-mute @DEFAULT_SOURCE@ toggle"
      ),
      ( (mod4Mask, xF86XK_AudioRaiseVolume),
        spawn "pactl set-source-mute @DEFAULT_SOURCE@ 0 && pactl set-source-volume @DEFAULT_SOURCE@ +2%"
      ),
      ( (mod4Mask, xF86XK_AudioLowerVolume),
        spawn "pactl set-source-volume @DEFAULT_SOURCE@ -2%"
      ),
      -- brightness
      ( (noModMask, xF86XK_MonBrightnessUp),
        spawn "light -A 20"
      ),
      ( (noModMask, xF86XK_MonBrightnessDown),
        spawn "light -U 20"
      ),
      -- copy/paste
      ( (modMask, xK_c),
        ifTerminal
          (sendKey noModMask xF86XK_Copy)
          (sendKey controlMask xK_c)
      ),
      ( (modMask, xK_v),
        ifTerminal
          (sendKey noModMask xF86XK_Paste)
          (sendKey controlMask xK_v)
      )
    ]
      ++ workspaceTagKeys
      ++ screenKeys
      ++ [ ( (modMask, xK_slash),
             submap . M.fromList $
               [ ( (modMask, xK_slash),
                   local
                     (setTerminal "alacritty --class=manpage")
                     (manPrompt xPConfig)
                 )
               ]
           )
         ]
      ++ [ ( (modMask, alt),
             submap . M.fromList $
               [ ( (noModMask, xK_a),
                   appendThoughtPrompt xPConfig
                 ),
                 ( (noModMask, xK_g),
                   gotoMenuArgs $ filter (not . (== '\'')) <$> dmenuArgs
                 ),
                 ( (noModMask, xK_m),
                   renameWorkspace xPConfig
                 ),
                 ( (noModMask, xK_r),
                   runOrRaisePrompt xPConfig
                 ),
                 ( (noModMask, xK_w),
                   workspacePrompt xPConfig (windows . W.view)
                 ),
                 ( (noModMask, xK_x),
                   xmonadPromptC commands xPConfig
                 ),
                 ( (noModMask, xK_y),
                   withWindowSet (trace . show . map W.tag . W.workspaces)
                 ),
                 ( (noModMask, xK_z),
                   spawn ("i3lock --color=" ++ grey0)
                 )
               ]
           )
           | alt <- [xK_Alt_L, xK_Alt_R]
         ]
  where
    -- mod-[1..9], Switch to workspace N
    -- mod-shift-[1..9], Move client to workspace N
    workspaceTagKeys =
      [ ( (m .|. modMask, k),
          windows =<< onCurrentScreenX f i
        )
        | (k, i) <- zip [xK_1..xK_9] (workspaces' conf),
          (m, f) <- [ (noModMask, pure . W.view),
                      (shiftMask, shiftRLWhen isFloat)
                    ]
      ]

    -- super-{w,e,r}, Switch to physical/Xinerama screens 1, 2, or 3
    -- super-shift-{w,e,r}, Move client to screen 1, 2, or 3
    screenKeys =
      [ ( (m .|. mod4Mask, key),
          screenWorkspace sc >>= flip whenJust (f >=> windows)
        )
        | (key, sc) <- zip [xK_w, xK_e, xK_r] [0..],
          (f, m) <- [ (pure . W.view, noModMask),
                      (shiftRLWhen isFloat, shiftMask)
                    ]
      ]

    onCurrentScreenX :: (PhysicalWorkspace -> X a) -> (VirtualWorkspace -> X a)
    onCurrentScreenX f vwsp =
      withCurrentScreen (f . flip marshall vwsp)

    fullToggleOff :: X ()
    fullToggleOff = do
      t <- isFullToggleOn
      when t (sendMessage ToggleLayout)

    isFullToggleOn :: X Bool
    isFullToggleOn =
      fmap ("Full" `isInfixOf`) layoutDescription

    layoutDescription :: X String
    layoutDescription = withWindowSet $
      pure . description . W.layout . W.workspace . W.current

    cycledWorkspace :: WSType
    cycledWorkspace =
      WSIs $ withCurrentScreen (pure . cycledWorkspaceOnScreen)

    cycledWorkspaceOnScreen :: ScreenId -> WindowSpace -> Bool
    cycledWorkspaceOnScreen sid wsp =
      all
        ($ wsp)
        [ (not . scratchpadWorkspace),
          (not . emptyWorkspace),
          isOnScreen sid
        ]

    emptyWorkspace :: WindowSpace -> Bool
    emptyWorkspace = null . W.stack

    scratchpadWorkspace :: WindowSpace -> Bool
    scratchpadWorkspace = null . namedScratchpadFilterOutWorkspace . (:[])

    isOnScreen :: ScreenId -> WindowSpace -> Bool
    isOnScreen s = (s ==) . unmarshallS . W.tag

    toggleRecentWS :: X ()
    toggleRecentWS =
      withWindowSet (windows . const . head . recentWS)

    recentWS :: WindowSet -> [WindowSet]
    recentWS ws = map (`W.view` ws) (recentTags ws)

    recentTags :: WindowSet -> [WorkspaceId]
    recentTags ws =
      map W.tag
        . filter (not . null . W.stack)
        . namedScratchpadFilterOutWorkspace
        $ map W.workspace (W.visible ws)
          ++ W.hidden ws
          ++ [W.workspace (W.current ws)]

    changeWorkspaceDir :: X ()
    changeWorkspaceDir =
      changeProjectDirPrompt' (ComplCaseSensitive False) xPConfig

    setTerminal :: String -> XConf -> XConf
    setTerminal t xc =
      xc {config = (config xc) {terminal = t}}

    ifTerminal :: X () -> X () -> X ()
    ifTerminal thenX elseX =
      bindFirst [(isTerminal, thenX), (pure True, elseX)]

    isTerminal :: Query Bool
    isTerminal = className =? "Alacritty"

    appendThoughtPrompt :: XPConfig -> X ()
    appendThoughtPrompt xP = do
      home <- io getHomeDirectory
      time <- maybe "" id <$> date "[%Y-%m-%dT%T%Z] "
      appendFilePrompt' xP (time ++) (home </> "thoughts")

    dmenu :: String
    dmenu =
      intercalate " " ("dmenu_run" : dmenuArgs)

    dmenuArgs :: [String]
    dmenuArgs =
      [ "-fn", "monospace:size=12",
        "-l", "24",
        "-i",
        "-nb", translate grey0,
        "-nf", translate grey6,
        "-sb", translate grey1,
        "-sf", translate white
      ]

    commands :: [(String, X ())]
    commands =
      [ ("shrink", sendMessage Shrink),
        ("expand", sendMessage Expand),
        ("refresh", refresh)
      ]

mouseBindings' :: XConfig Layout -> Map (KeyMask, Button) (Window -> X ())
mouseBindings' XConfig {modMask} =
  M.fromList $
    [ ( (modMask, button1),
        \w ->
          focus w
            >> mouseMoveWindow w
            >> windows W.shiftMaster
      ),
      ( (mod4Mask, button1),
        \w ->
          focus w
            >> mouseResizeEdgeWindow (3/4) w
            >> windows W.shiftMaster
      )
    ]

xPConfig :: XPConfig
xPConfig =
  def
    { position          = Top,
      height            = 25,
      alwaysHighlight   = False,
      promptBorderWidth = 0,
      promptKeymap      = keymap `M.union` defaultXPKeymap,
      bgColor           = grey0,
      fgColor           = grey5,
      bgHLight          = grey7,
      fgHLight          = grey0,
      font              = "xft:monospace:size=12"
    }
  where
    keymap = M.fromList $
      [ ((controlMask, xK_p), moveHistory W.focusUp'),
        ((mod1Mask,    xK_p), moveHistory W.focusUp'),
        ((controlMask, xK_n), moveHistory W.focusDown'),
        ((mod1Mask,    xK_n), moveHistory W.focusDown')
      ]

scratchpads :: [NamedScratchpad]
scratchpads =
  [ scratchTerminal
  ]

scratchTerminal :: NamedScratchpad
scratchTerminal =
  NS name command (appName =? name) (doCenteredFloat 0.8 0.7)
  where
    name :: String
    name = "scratchpad"

    command :: String
    command = "alacritty-transparent --class " ++ name

doCenteredFloat :: Rational -> Rational -> ManageHook
doCenteredFloat width height =
  doRectFloat (W.RationalRect x y width height)
  where
    x :: Rational
    x = (1 - width) / 2

    y :: Rational
    y = (1 - height) / 2

withCurrentScreen :: (ScreenId -> X a) -> X a
withCurrentScreen f =
  withWindowSet (f . W.screen . W.current)

------------------------------------------------------------------------
-- Window rules:

-- Execute arbitrary actions and WindowSet manipulations when managing
-- a new window. You can use this to, for example, always float a
-- particular program, or have a client always appear on a particular
-- workspace.
--
-- To find the property name associated with a program, use
-- > xprop | grep WM_CLASS
-- and click on the client you're interested in.
--
-- To match on the WM_NAME, you can use 'title' in the same way that
-- 'className' and 'appName' are used below.
--
manageHook' :: ManageHook
manageHook' =
  composeAll
    [ insertPosition Above Newer,
      composeOne
        [ isDialog -?> doFloat,
          -- isFullscreen -?> doFullFloat,
          className =? "Gcr-prompter" -?> doCenterFloat,
          className =? "Xmessage" -?> doCenterFloat,
          -- className =? "vlc" -?> doFloat,
          appName =? "desktop_window" -?> doIgnore,
          appName =? "manpage" -?> doCenteredFloat 0.6 0.6
        ],
      -- fullscreenManageHook,
      namedScratchpadManageHook scratchpads
    ]

------------------------------------------------------------------------
-- Event handling

-- * EwmhDesktops users should change this to ewmhDesktopsEventHook
--
-- Defines a custom handler function for X Events. The function should
-- return (All True) if the default handler is to be run afterwards. To
-- combine event hooks use mappend or mconcat from Data.Monoid.
--
eventHook :: Event -> X All
eventHook =
  dynStatusBarEventHook xmobar killAlsactl
    <> refocusLastWhen isFloat
    <> fullscreenEventHook

------------------------------------------------------------------------
-- Status bars and logging

-- Perform an arbitrary action on each internal state change or X event.
-- See the 'XMonad.Hooks.DynamicLog' extension for examples.
--
logHook' :: X ()
logHook' = multiPP currentScreenPP nonCurrentScreenPP
  where
    multiPP :: PP -> PP -> X ()
    multiPP = multiPPFormat (withCurrentScreen . logString)

    logString :: PP -> ScreenId -> X String
    logString pp =
      (workspaceNamesPP >=> dynamicLogString)
        . namedScratchpadFilterOutWorkspacePP
        . flip marshallPP pp

    currentScreenPP :: PP
    currentScreenPP = barPP

    nonCurrentScreenPP :: PP
    nonCurrentScreenPP = barPP

    barPP :: PP
    barPP =
      xmobarPP
        { ppCurrent = xmobarColor grey7 blue . pad,
          ppHidden  = xmobarColor grey4 grey1 . pad,
          ppSep     = " ",
          ppWsSep   = "",
          ppTitle   = const "",
          ppLayout  = ppLayout'
        }

    ppLayout' :: String -> String
    ppLayout' s
      | "Full"  `isInfixOf` s = xmobarColor cyan "" "·"
      | "Limit" `isInfixOf` s = xmobarColor grey2 "" "·"
      | otherwise             = ""

------------------------------------------------------------------------
-- Startup hook

startupHook' :: X ()
startupHook' = do
  io killAlsactl
  dynStatusBarStartup xmobar killAlsactl

xmobar :: ScreenId -> IO Handle
xmobar (S sid) = spawnPipe $
  unwords
    [ "xmobar",
      "-B", translate black,
      "-F", translate grey6,
      "-f", "xft:monospace:size=11",
      "-N", "xft:FontAwesome:size=11",
      "-i", "/run/current-system/sw/share/icons/xmobar",
      "-x", show sid,
      "-t", translate (template sid),
      "-c", translate $ list (commands sid)
    ]
  where
    template 0 = xmobarMainTemplate
    template _ = xmobarAuxTemplate

    commands 0 = xmobarMainCommands
    commands _ = xmobarAuxCommands

xmobarMainTemplate :: String
xmobarMainTemplate =
  concat
    [ cmdSep "StdinReader",
      pad "}{",
      cmdSep "disku",
      " ",
      xmobarColor cyan "" "·",
      cmdSep "cpu",
      "  ",
      fontN 1 $ xmobarColor grey2 "" (cmdSep "vpn"),
      pad (cmdSep "wlp58s0wi"),
      pad (cmdSep "battery"),
      pad (cmdSep "alsa:default:Master"),
      pad (cmdSep "date")
    ]

xmobarAuxTemplate :: String
xmobarAuxTemplate =
  xmobarMainTemplate

xmobarMainCommands :: [String]
xmobarMainCommands =
  map unwords [disk, cpu, vpn, wireless, battery, volume, date', stdinReader]
  where
    disk =
      [ "Run DiskU",
        brackets $ show ("/", "<free>"),
        list (map quote diskArgs),
        "50"
      ]
    diskArgs =
      [ "--Low"   , "5",
        "--high"  , grey3,
        "--normal", grey3,
        "--low"   , red
      ]

    cpu = ["Run Cpu", list (map quote cpuArgs), "50"]
    cpuArgs =
      [ "--template", "<total>",
        "--ppad"    , "2",
        "--High"    , "50",
        "--Low"     , "3",
        "--high"    , orange,
        "--normal"  , grey2,
        "--low"     , grey2
      ]

    vpn = ["Run Com", quote "bleep", "[]", quote "vpn", "50"]

    wireless =
      [ "Run Wireless",
        quote "wlp58s0",
        list $ map quote ["--template", "<essid>"],
        "50"
      ]

    battery = ["Run Battery", list (map quote batteryArgs), "20"]
    batteryArgs =
      [ "--template", "<acstatus>",
        "--",
        "--on-icon-pattern"  , icon "battery/on/battery_on_%%.xpm",
        "--idle-icon-pattern", icon "battery/idle/battery_idle_%%.xpm",
        "--off-icon-pattern" , icon "battery/off/battery_off_%%.xpm",
        "--on"               , "<leftipat>",
        "--idle"             , "<leftipat>",
        "--off"              , "<leftipat>"
      ]

    volume =
      ["Run Alsa", quote "default", quote "Master", list (map quote volumeArgs)]
    volumeArgs =
      [ "--template", "<status>",
        "--",
        "--on"  , fontN 1 "\xf026" ++ "<volume>",
        "--off" , fontN 1 "\xf026" ++ "<volume>",
        "--onc" , grey6,
        "--offc", grey2
      ]

    date' = ["Run Date", quote dateFormat, quote "date", "50"]
    dateFormat = "%a %b %-d " ++ xmobarColor chalk "" "%l:%M"

    stdinReader = ["Run StdinReader"]

xmobarAuxCommands :: [String]
xmobarAuxCommands = xmobarMainCommands

list :: [String] -> String
list = brackets . commas

brackets :: String -> String
brackets = wrap "[" "]"

commas :: [String] -> String
commas = intercalate ","

quote :: String -> String
quote = wrap "\"" "\""

icon :: String -> String
icon = wrap "<icon=" "/>"

fontN :: Int -> String -> String
fontN n = wrap ("<fn=" ++ show n ++ ">") "</fn>"

cmdSep :: String -> String
cmdSep = wrap "%" "%"

-- https://github.com/jaor/xmobar/issues/432
killAlsactl :: MonadIO m => m ()
killAlsactl = spawn $
  intercalate
    " | "
    [ "ps axo pid,s,command",
      "awk '/alsactl monitor default$/{print $1}'",
      "xargs --no-run-if-empty kill 2>/dev/null"
    ]

type SmartBorders a = ModifiedLayout SmartBorder a
type Refocus      a = ModifiedLayout RefocusLastLayoutHook (FocusTracking a)
type Boring       a = ModifiedLayout BoringWindows a
type ToggleFull   a = ToggleLayouts Full a
type Renamed      a = ModifiedLayout Rename a
type LimitSelect  a = ModifiedLayout Selection a

type Layouts
  = Choose
      ResizableTall
      ( Choose
          (Renamed (LimitSelect ResizableTall))
          (Mirror (LimitSelect ResizableTall))
      )

layoutHook' :: SmartBorders (Refocus (Boring (ToggleFull Layouts))) Window
layoutHook' =
  id
    . smartBorders
    . refocusLastLayoutHook
    . focusTracking
    . boringAuto
    . toggleLayouts Full
    -- . fullscreenFloat
    $ tall ||| rename (limit tall) ||| Mirror (limit tall)
  where
    limit :: l Window -> LimitSelect l Window
    limit = limitSelect 1 1

    rename :: l Window -> Renamed l Window
    rename = renamed [Prepend "Limit (", Append ")"]

    tall :: ResizableTall Window
    tall = ResizableTall 1 (3/100) (1/2) []

black, grey0, grey1, grey2, grey3, grey4, grey6, grey5, grey7, white :: String
black = "#161616"
grey0 = "#1c1c1c"
grey1 = "#212121"
grey2 = "#525d6a"
grey3 = "#787888"
grey4 = "#888888"
grey5 = "#aaaaaa"
grey6 = "#a8b8b8"
grey7 = "#dddddd"
white = "#ffffff"

chalk, blue, cyan, orange, red :: String
chalk  = "#c1f0f7"
blue   = "#004466"
cyan   = "#9bd4ff"
orange = "#ffbb49"
red    = "#fe3d2a"
