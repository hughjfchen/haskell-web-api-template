{-# LANGUAGE OverloadedStrings, DeriveGeneric, UnicodeSyntax #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances, UndecidableInstances #-}
module Logging
  (
    module Logging
  , module X
  )
where

import qualified  Data.Text as T
import qualified  Data.Text.Encoding as T
import Data.Has as X
import Data.Aeson
import           Control.Monad.Reader (MonadReader, asks)
import           RIO
import           System.Log.FastLogger
import           System.Log.FastLogger as X (LogType (..), defaultBufSize)

type ModLogger = LogFunc

type Formatter = TimedFastLogger → CallStack → LogSource → LogLevel → Utf8Builder → IO ()

data LogMessage = LogMessage {
  message        :: !Text
  , logSource :: !Text
  , callStack :: !Text
  , timestamp    :: !Text
  , level        :: !Text
  , appVersion     :: !Text
  , appEnvironment :: !Text
} deriving (Eq, Show, Generic)

instance ToJSON LogMessage where
  toEncoding = genericToEncoding defaultOptions

instance ToLogStr LogMessage where
  toLogStr a = (toLogStr . encode $ a) <> "\n"

-- | Creates a logger module using a given formatting function.
-- | Also returns the underlying TimedFastLogger for use outside of your app (e.g. in some WAI middleware).
newLogger ∷ LogType → Formatter → IO (TimedFastLogger, ModLogger)
newLogger logtype formatter = do
  tc ← newTimeCache simpleTimeFormat'
  (fl, _cleanupAction) ← newTimedFastLogger tc logtype
  -- todo clean up
  return (fl, mkLogFunc $ formatter fl)

jsonFormatter ∷ Formatter
jsonFormatter logger cs src logLvl msg = logger buildJsonLogMsg
  where
    showLevel LevelDebug = "debug"
    showLevel LevelInfo = "info"
    showLevel LevelWarn = "warn"
    showLevel LevelError = "error"
    showLevel (LevelOther t) = "" <> t <> ""
    buildJsonLogMsg t =
      toLogStr $
      LogMessage
        (utf8BuilderToText msg)
        (utf8BuilderToText . displayBytesUtf8 . fromLogStr . toLogStr $ src)
        (utf8BuilderToText $ displayCallStack cs)
        (T.decodeUtf8 t)
        (showLevel logLvl)
        "1.0"
        "dev"

instance {-# OVERLAPPABLE #-} Has ModLogger α ⇒ HasLogFunc α where
  logFuncL = hasLens

-- | Gets a value of any type from the context.
askObj ∷ (Has β α, MonadReader α μ) ⇒ μ β
askObj = asks getter

-- | Gets a thing from a value of any type from the context. (Useful for configuration fields.)
askOpt ∷ (Has β α, MonadReader α μ) ⇒ (β → ψ) → μ ψ
askOpt f = asks $ f . getter