{-# LANGUAGE NamedFieldPuns #-}

import XMonad
    (ChangeLayout(NextLayout), Choose, Full, IncMasterN(IncMasterN), Layout, ManageHook, Mirror,
     Resize(Expand, Shrink), Tall, X, XConfig(XConfig), (=?), (-->), className, clickJustFocuses,
     composeAll, doFloat, doIgnore, focusedBorderColor, handleEventHook, io, keys, kill, layoutHook,
     logHook, manageHook, modMask, normalBorderColor, resource, screenWorkspace, sendMessage, spawn,
     startupHook, terminal, whenJust, windows, withFocused, workspaces, xmonad
    )
import XMonad.Actions.CycleWS (Direction1D(Next, Prev), WSType(NonEmptyWS), moveTo, toggleWS)
import XMonad.Hooks.DynamicLog (ppOutput, ppTitle, statusBar, xmobarColor, xmobarPP, ppCurrent, ppHidden, ppLayout, ppWsSep, wrap)
import XMonad.Hooks.ManageDocks (AvoidStruts, avoidStruts, manageDocks)
import XMonad.Hooks.ManageHelpers (doCenterFloat)
import XMonad.Layout.LayoutModifier (ModifiedLayout)
import XMonad.Layout.NoBorders (SmartBorder, smartBorders)
import XMonad.StackSet
    (focusDown, focusUp, focusMaster, shift, swapMaster, swapDown, swapUp,
     sink, greedyView, view
    )
import Graphics.X11
    (KeyMask, KeySym, Window, controlMask, mod4Mask, noModMask, shiftMask, xK_1, xK_9, xK_b, xK_d, xK_e, xK_h, xK_j,
     xK_k, xK_l, xK_m, xK_r, xK_t, xK_w, xK_q, xK_z, xK_Return, xK_Tab, xK_comma, xK_period, xK_space,
     xK_Print
    )
import Graphics.X11.ExtraTypes
    (xF86XK_AudioRaiseVolume, xF86XK_AudioLowerVolume, xF86XK_AudioMute, xF86XK_MonBrightnessUp, xF86XK_MonBrightnessDown
    )
import Graphics.X11.Xlib.Extras (Event)
import Data.Bits ((.|.))
import Data.Default (def)
import Data.Monoid (All)
import System.Exit (ExitCode(ExitSuccess), exitWith)

import qualified Data.Map as M


-- https://github.com/xmonad/X11/blob/6e5ef8019a0cc49e18410a335dbdeea87b7c4aac/Graphics/X11/Types.hsc
-- https://hackage.haskell.org/package/xmonad-contrib-0.16/docs/XMonad-Util-Paste.html
-- https://stackoverflow.com/questions/6605399/how-can-i-set-an-action-to-occur-on-a-key-release-in-xmonad

keys' :: XConfig Layout -> M.Map (KeyMask, KeySym) (X ())
keys' conf@(XConfig {modMask}) = M.fromList $
    -- launch/kill
    [ ((modShiftMask,       xK_Return), spawn $ terminal conf)
    , ((modMask,            xK_space ), spawn "dmenu_run -fn monospace:size=12 -l 16 -i -nb '#1c1c1c' -nf '#a5adb7' -sb '#1f1f1f' -sf '#c8f5ff'")
    , ((modShiftMask,       xK_z     ), spawn "i3lock --color=1d1d1d")
    , ((noModMask,          xK_Print ), spawn "screenshot")
    , ((controlMask,        xK_Print ), spawn "screenshot -c")
    , ((shiftMask,          xK_Print ), spawn "screenshot -a")
    , ((controlShiftMask,   xK_Print ), spawn "screenshot -a -c")
    , ((modShiftMask,       xK_d     ), kill)

    -- layout algorithms
    , ((modShiftMask,       xK_space ), sendMessage NextLayout)

    -- focus
    , ((modMask,            xK_Tab   ), windows focusDown)
    , ((modMask,            xK_j     ), windows focusDown)
    , ((modMask,            xK_k     ), windows focusUp  )
    , ((modMask,            xK_m     ), windows focusMaster)

    -- swap
    , ((modMask,            xK_Return), windows swapMaster)
    , ((modShiftMask,       xK_j     ), windows swapDown  )
    , ((modShiftMask,       xK_k     ), windows swapUp    )

    -- resize
    , ((modMask,            xK_h     ), sendMessage Shrink)
    , ((modMask,            xK_l     ), sendMessage Expand)

    -- tile
    , ((modMask,            xK_t     ), withFocused $ windows . sink)

    -- increment/decrement master area
    , ((modShiftMask,       xK_comma ), sendMessage (IncMasterN 1))
    , ((modShiftMask,       xK_period), sendMessage (IncMasterN (-1)))

    -- quit or restart
    , ((mod4ShiftMask,      xK_q     ), io (exitWith ExitSuccess))
    , ((mod4Mask,           xK_q     ), spawn "xmonad --recompile && xmonad --restart")

    -- volume
    , ((noModMask, xF86XK_AudioRaiseVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ +1%")
    , ((noModMask, xF86XK_AudioLowerVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ -1%")
    , ((noModMask, xF86XK_AudioMute       ), spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle")

    -- brightness
    , ((noModMask, xF86XK_MonBrightnessUp  ), spawn "light -A 10")
    , ((noModMask, xF86XK_MonBrightnessDown), spawn "light -U 10")

    -- workspaces
    , ((controlMask,        xK_period), moveTo Next NonEmptyWS)
    , ((controlMask,        xK_comma ), moveTo Prev NonEmptyWS)
    , ((modMask,            xK_l     ), toggleWS)
    ]
    ++
    -- mod-[1..9], Switch to workspace N
    -- mod-shift-[1..9], Move client to workspace N
    [ ((m .|. modMask, k), windows $ f i)
      | (i, k) <- zip (workspaces conf) [xK_1..xK_9]
      , (f, m) <- [(greedyView, noModMask), (shift, shiftMask)]
    ]
    ++
    -- super-{w,e,r}, Switch to physical/Xinerama screens 1, 2, or 3
    -- super-shift-{w,e,r}, Move client to screen 1, 2, or 3
    --
    [ ((m .|. mod4Mask, key), screenWorkspace sc >>= flip whenJust (windows . f))
      | (key, sc) <- zip [xK_w, xK_e, xK_r] [0..]
      , (f, m) <- [(view, noModMask), (shift, shiftMask)]
    ]
  where
    modShiftMask = modMask .|. shiftMask
    mod4ShiftMask = mod4Mask .|. shiftMask
    controlShiftMask = controlMask .|. shiftMask

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
-- 'className' and 'resource' are used below.
--
manageHook' :: ManageHook
manageHook' = composeAll
    [ className =? "Gcr-prompter"   --> doCenterFloat
    , className =? "vlc"            --> doFloat
    , resource  =? "desktop_window" --> doIgnore
    , manageDocks
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
eventHook = mempty

------------------------------------------------------------------------
-- Status bars and logging

-- Perform an arbitrary action on each internal state change or X event.
-- See the 'XMonad.Hooks.DynamicLog' extension for examples.
--
logHook' :: X ()
logHook' = pure ()

------------------------------------------------------------------------
-- Startup hook

-- Perform an arbitrary action each time xmonad starts or is restarted
-- with mod-q.  Used by, e.g., XMonad.Layout.PerWorkspace to initialize
-- per-workspace layout choices.
--
-- By default, do nothing.
startupHook' :: X ()
startupHook' = pure ()


layout
    :: ModifiedLayout
         AvoidStruts
         ( ModifiedLayout
             SmartBorder
             (Choose Tall (Choose (Mirror Tall) Full))
         )
         Window
layout =
    avoidStruts
    . smartBorders
    $ layoutHook def


main :: IO ()
main =
    xmonad =<< statusBar "xmobar" barPP toggleStrutsKey config
  where
    config = def
        { layoutHook         = layout
        , terminal           = "alacritty"
        , clickJustFocuses   = False
        , normalBorderColor  = "gray13" -- "#212121"
        , focusedBorderColor = "gray29" -- "#4A4A4A"
        , keys               = keys'
        , manageHook         = manageHook'
        , handleEventHook    = eventHook
        , logHook            = logHook'
        , startupHook        = startupHook'
        }

    barPP = xmobarPP
        { ppCurrent = xmobarColor "#dddddd" "#004466" . wrap " " " "
        , ppHidden  = xmobarColor "#888888" "#222222" . wrap " " " "
        , ppWsSep = ""
        , ppTitle = const ""
        , ppLayout = const ""
        }

    toggleStrutsKey XConfig {modMask} = (modMask .|. shiftMask, xK_b)
