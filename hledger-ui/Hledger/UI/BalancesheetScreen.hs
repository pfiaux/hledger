-- The balance sheet screen, like the accounts screen but restricted to balance sheet accounts.

{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Hledger.UI.BalancesheetScreen
 (bsNew
 ,bsUpdate
 ,bsDraw
 ,bsHandle
 ,bsSetSelectedAccount
 )
where

import Brick hiding (bsDraw)
import Brick.Widgets.List
import Brick.Widgets.Edit
import Control.Monad
import Control.Monad.IO.Class (liftIO)
import qualified Data.Text as T
import Data.Time.Calendar (Day)
import qualified Data.Vector as V
import Data.Vector ((!?))
import Graphics.Vty (Event(..),Key(..),Modifier(..), Button (BLeft, BScrollDown, BScrollUp))
import Lens.Micro.Platform
import System.Console.ANSI

import Hledger
import Hledger.Cli hiding (mode, progname, prognameandversion)
import Hledger.UI.UIOptions
import Hledger.UI.UITypes
import Hledger.UI.UIState
import Hledger.UI.UIUtils
import Hledger.UI.UIScreens
import Hledger.UI.Editor
import Hledger.UI.ErrorScreen (uiReloadJournal, uiCheckBalanceAssertions, uiReloadJournalIfChanged)
import Hledger.UI.AccountsScreen (asDrawHelper)
import Hledger.UI.RegisterScreen (rsCenterSelection)


bsDraw :: UIState -> [Widget Name]
bsDraw ui = dlogUiTrace "bsDraw" $ asDrawHelper ui ropts' scrname showbalchgkey
  where
    scrname = "balance sheet"
    ropts' = (_rsReportOpts $ reportspec_ $ uoCliOpts $ aopts ui){balanceaccum_=Historical}
    showbalchgkey = False

bsHandle :: BrickEvent Name AppEvent -> EventM Name UIState ()
bsHandle ev = do
  ui0 <- get'
  dlogUiTraceM "bsHandle 1"
  case ui0 of
    ui1@UIState{
       aopts=UIOpts{uoCliOpts=copts}
      ,ajournal=j
      ,aMode=mode
      ,aScreen=BS sst
      } -> do

      let
        -- save the currently selected account, in case we leave this screen and lose the selection
        selacct = case listSelectedElement $ _assList sst of
                    Just (_, AccountsScreenItem{..}) -> asItemAccountName
                    Nothing -> sst ^. assSelectedAccount
        ui = ui1{aScreen=BS sst{_assSelectedAccount=selacct}}
        nonblanks = V.takeWhile (not . T.null . asItemAccountName) $ listElements $ _assList sst
        lastnonblankidx = max 0 (length nonblanks - 1)
        journalspan = journalDateSpan False j
      d <- liftIO getCurrentDay

      case mode of
        Minibuffer _ ed ->
          case ev of
            VtyEvent (EvKey KEsc   []) -> put' $ closeMinibuffer ui
            VtyEvent (EvKey KEnter []) -> put' $ regenerateScreens j d $
                case setFilter s $ closeMinibuffer ui of
                  Left bad -> showMinibuffer "Cannot compile regular expression" (Just bad) ui
                  Right ui' -> ui'
              where s = chomp $ unlines $ map strip $ getEditContents ed
            VtyEvent (EvKey (KChar 'l') [MCtrl]) -> redraw
            VtyEvent (EvKey (KChar 'z') [MCtrl]) -> suspend ui
            VtyEvent e -> do
              ed' <- nestEventM' ed $ handleEditorEvent (VtyEvent e)
              put' ui{aMode=Minibuffer "filter" ed'}
            AppEvent _  -> return ()
            MouseDown{} -> return ()
            MouseUp{}   -> return ()

        Help ->
          case ev of
            -- VtyEvent (EvKey (KChar 'q') []) -> halt
            VtyEvent (EvKey (KChar 'l') [MCtrl]) -> redraw
            VtyEvent (EvKey (KChar 'z') [MCtrl]) -> suspend ui
            _ -> helpHandle ev

        Normal ->
          case ev of
            VtyEvent (EvKey (KChar 'q') []) -> halt
            -- EvKey (KChar 'l') [MCtrl] -> do
            VtyEvent (EvKey KEsc        []) -> put' $ resetScreens d ui
            VtyEvent (EvKey (KChar c)   []) | c == '?' -> put' $ setMode Help ui
            -- XXX AppEvents currently handled only in Normal mode
            -- XXX be sure we don't leave unconsumed events piling up
            AppEvent (DateChange old _) | isStandardPeriod p && p `periodContainsDate` old ->
              put' $ regenerateScreens j d $ setReportPeriod (DayPeriod d) ui
              where
                p = reportPeriod ui
            e | e `elem` [VtyEvent (EvKey (KChar 'g') []), AppEvent FileChange] ->
              liftIO (uiReloadJournal copts d ui) >>= put'
            VtyEvent (EvKey (KChar 'I') []) -> put' $ uiCheckBalanceAssertions d (toggleIgnoreBalanceAssertions ui)
            VtyEvent (EvKey (KChar 'a') []) -> suspendAndResume $ clearScreen >> setCursorPosition 0 0 >> add copts j >> uiReloadJournalIfChanged copts d j ui
            VtyEvent (EvKey (KChar 'A') []) -> suspendAndResume $ void (runIadd (journalFilePath j)) >> uiReloadJournalIfChanged copts d j ui
            VtyEvent (EvKey (KChar 'E') []) -> suspendAndResume $ void (runEditor endPosition (journalFilePath j)) >> uiReloadJournalIfChanged copts d j ui
            VtyEvent (EvKey (KChar 'B') []) -> put' $ regenerateScreens j d $ toggleConversionOp ui
            VtyEvent (EvKey (KChar 'V') []) -> put' $ regenerateScreens j d $ toggleValue ui
            VtyEvent (EvKey (KChar '0') []) -> put' $ regenerateScreens j d $ setDepth (Just 0) ui
            VtyEvent (EvKey (KChar '1') []) -> put' $ regenerateScreens j d $ setDepth (Just 1) ui
            VtyEvent (EvKey (KChar '2') []) -> put' $ regenerateScreens j d $ setDepth (Just 2) ui
            VtyEvent (EvKey (KChar '3') []) -> put' $ regenerateScreens j d $ setDepth (Just 3) ui
            VtyEvent (EvKey (KChar '4') []) -> put' $ regenerateScreens j d $ setDepth (Just 4) ui
            VtyEvent (EvKey (KChar '5') []) -> put' $ regenerateScreens j d $ setDepth (Just 5) ui
            VtyEvent (EvKey (KChar '6') []) -> put' $ regenerateScreens j d $ setDepth (Just 6) ui
            VtyEvent (EvKey (KChar '7') []) -> put' $ regenerateScreens j d $ setDepth (Just 7) ui
            VtyEvent (EvKey (KChar '8') []) -> put' $ regenerateScreens j d $ setDepth (Just 8) ui
            VtyEvent (EvKey (KChar '9') []) -> put' $ regenerateScreens j d $ setDepth (Just 9) ui
            VtyEvent (EvKey (KChar '-') []) -> put' $ regenerateScreens j d $ decDepth ui
            VtyEvent (EvKey (KChar '_') []) -> put' $ regenerateScreens j d $ decDepth ui
            VtyEvent (EvKey (KChar c)   []) | c `elem` ['+','='] -> put' $ regenerateScreens j d $ incDepth ui
            VtyEvent (EvKey (KChar 'T') []) -> put' $ regenerateScreens j d $ setReportPeriod (DayPeriod d) ui

            -- display mode/query toggles
            -- VtyEvent (EvKey (KChar 'H') []) -> modify' (regenerateScreens j d . toggleHistorical) >> bsCenterAndContinue
            VtyEvent (EvKey (KChar 't') []) -> modify' (regenerateScreens j d . toggleTree) >> bsCenterAndContinue
            VtyEvent (EvKey (KChar c) []) | c `elem` ['z','Z'] -> modify' (regenerateScreens j d . toggleEmpty) >> bsCenterAndContinue
            VtyEvent (EvKey (KChar 'R') []) -> modify' (regenerateScreens j d . toggleReal) >> bsCenterAndContinue
            VtyEvent (EvKey (KChar 'U') []) -> modify' (regenerateScreens j d . toggleUnmarked) >> bsCenterAndContinue
            VtyEvent (EvKey (KChar 'P') []) -> modify' (regenerateScreens j d . togglePending) >> bsCenterAndContinue
            VtyEvent (EvKey (KChar 'C') []) -> modify' (regenerateScreens j d . toggleCleared) >> bsCenterAndContinue
            VtyEvent (EvKey (KChar 'F') []) -> modify' (regenerateScreens j d . toggleForecast d)

            VtyEvent (EvKey (KDown)     [MShift]) -> put' $ regenerateScreens j d $ shrinkReportPeriod d ui
            VtyEvent (EvKey (KUp)       [MShift]) -> put' $ regenerateScreens j d $ growReportPeriod d ui
            VtyEvent (EvKey (KRight)    [MShift]) -> put' $ regenerateScreens j d $ nextReportPeriod journalspan ui
            VtyEvent (EvKey (KLeft)     [MShift]) -> put' $ regenerateScreens j d $ previousReportPeriod journalspan ui
            VtyEvent (EvKey (KChar '/') []) -> put' $ regenerateScreens j d $ showMinibuffer "filter" Nothing ui
            VtyEvent (EvKey k           []) | k `elem` [KBS, KDel] -> (put' $ regenerateScreens j d $ resetFilter ui)
            VtyEvent e | e `elem` moveLeftEvents -> put' $ popScreen ui
            VtyEvent (EvKey (KChar 'l') [MCtrl]) -> scrollSelectionToMiddle (_assList sst) >> redraw
            VtyEvent (EvKey (KChar 'z') [MCtrl]) -> suspend ui

            -- exit screen on LEFT
            VtyEvent e | e `elem` moveLeftEvents -> put' $ popScreen ui
            -- or on a click in the app's left margin. This is a VtyEvent since not in a clickable widget.
            VtyEvent (EvMouseUp x _y (Just BLeft)) | x==0 -> put' $ popScreen ui

            -- enter register screen for selected account (if there is one),
            -- centering its selected transaction if possible
            -- XXX should propagate ropts{balanceaccum_=Historical}
            VtyEvent e | e `elem` moveRightEvents
                      , not $ isBlankElement $ listSelectedElement (_assList sst) -> bsEnterRegisterScreen d selacct ui

            -- MouseDown is sometimes duplicated, https://github.com/jtdaugherty/brick/issues/347
            -- just use it to move the selection
            MouseDown _n BLeft _mods Location{loc=(_x,y)} | not $ (=="") clickedacct -> do
              put' ui{aScreen=BS sst}  -- XXX does this do anything ?
              where clickedacct = maybe "" asItemAccountName $ listElements (_assList sst) !? y
            -- and on MouseUp, enter the subscreen
            MouseUp _n (Just BLeft) Location{loc=(_x,y)} | not $ (=="") clickedacct -> do
              bsEnterRegisterScreen d clickedacct ui
              where clickedacct = maybe "" asItemAccountName $ listElements (_assList sst) !? y

            -- when selection is at the last item, DOWN scrolls instead of moving, until maximally scrolled
            VtyEvent e | e `elem` moveDownEvents, isBlankElement mnextelement -> do
              vScrollBy (viewportScroll $ (_assList sst)^.listNameL) 1
              where mnextelement = listSelectedElement $ listMoveDown (_assList sst)

            -- mouse scroll wheel scrolls the viewport up or down to its maximum extent,
            -- pushing the selection when necessary.
            MouseDown name btn _mods _loc | btn `elem` [BScrollUp, BScrollDown] -> do
              let scrollamt = if btn==BScrollUp then -1 else 1
              list' <- nestEventM' (_assList sst) $ listScrollPushingSelection name (bsListSize (_assList sst)) scrollamt
              put' ui{aScreen=BS sst{_assList=list'}}

            -- if page down or end leads to a blank padding item, stop at last non-blank
            VtyEvent e@(EvKey k           []) | k `elem` [KPageDown, KEnd] -> do
              l <- nestEventM' (_assList sst) $ handleListEvent e
              if isBlankElement $ listSelectedElement l
              then do
                let l' = listMoveTo lastnonblankidx l
                scrollSelectionToMiddle l'
                put' ui{aScreen=BS sst{_assList=l'}}
              else
                put' ui{aScreen=BS sst{_assList=l}}

            -- fall through to the list's event handler (handles up/down)
            VtyEvent e -> do
              list' <- nestEventM' (_assList sst) $ handleListEvent (normaliseMovementKeys e)
              put' ui{aScreen=BS $ sst & assList .~ list' & assSelectedAccount .~ selacct }

            MouseDown{} -> return ()
            MouseUp{}   -> return ()
            AppEvent _  -> return ()

    _ -> dlogUiTraceM "bsHandle 2" >> errorWrongScreenType "event handler"

bsEnterRegisterScreen :: Day -> AccountName -> UIState -> EventM Name UIState ()
bsEnterRegisterScreen d acct ui@UIState{ajournal=j, aopts=uopts} = do
  dlogUiTraceM "bsEnterRegisterScreen"
  let
    regscr = rsNew uopts d j acct isdepthclipped
      where
        isdepthclipped = case getDepth ui of
                          Just de -> accountNameLevel acct >= de
                          Nothing -> False
    ui1 = pushScreen regscr ui
  rsCenterSelection ui1 >>= put'

-- | Set the selected account on an accounts screen. No effect on other screens.
bsSetSelectedAccount :: AccountName -> Screen -> Screen
bsSetSelectedAccount a (BS sst@ASS{}) = BS sst{_assSelectedAccount=a}
bsSetSelectedAccount _ s = s

isBlankElement mel = ((asItemAccountName . snd) <$> mel) == Just ""

-- | Scroll the accounts screen's selection to the center. No effect if on another screen.
bsCenterAndContinue :: EventM Name UIState ()
bsCenterAndContinue = do
  ui <- get'
  case aScreen ui of
    BS sst -> scrollSelectionToMiddle $ _assList sst
    _ -> return ()

bsListSize = V.length . V.takeWhile ((/="").asItemAccountName) . listElements

