{-# LANGUAGE OverloadedStrings #-}

module Chakra.RequestLogging 
  (jsonRequestLogger) 
where

import           Data.Aeson                           as X (KeyValue ((.=)),
                                                            ToJSON (toJSON),
                                                            Value (String),
                                                            encode, object)
import qualified Data.ByteString.Builder              as BB (toLazyByteString)
import qualified Data.ByteString.Char8                as S8
import           Data.ByteString.Lazy                 (toStrict)
import           Data.Default                         (Default (def))
import           Data.IP                              (fromHostAddress,
                                                       fromIPv4)
import qualified Data.Text                            as T
import           Data.Text.Encoding                   (decodeUtf8With)
import           Data.Text.Encoding.Error             (lenientDecode)
import           Data.Time                            (NominalDiffTime)
import           Network.HTTP.Types                   as H (HttpVersion (HttpVersion),
                                                            QueryItem,
                                                            Status (statusCode))
import           Network.Socket                       (PortNumber,
                                                       SockAddr (..))
import           Network.Wai
import           Network.Wai.Middleware.RequestLogger (OutputFormat (..), OutputFormatterWithDetails,
                                                       mkRequestLogger,
                                                       outputFormat)
import           RIO                                  (Word32, Text, maybeToList)
import           System.Log.FastLogger                (toLogStr)
import           Text.Printf                          (printf)

-- | JSON formatted request log middleware for WAI applications
-- | it logs the given appName and appVer values
jsonRequestLogger :: Text -> Text -> IO Middleware
jsonRequestLogger envName appVer =
  mkRequestLogger $
  def {outputFormat = CustomOutputFormatWithDetails (formatAsJSONCustom envName appVer)}

formatAsJSONCustom :: Text -> Text -> OutputFormatterWithDetails
formatAsJSONCustom envName appVer date req status responseSize duration reqBody response =
  toLogStr
    (encode $
     object
       [ "env" .= envName
       , "appVersion" .= appVer
       , "request" .= requestToJSON req reqBody (Just duration)
       , "response" .=
         object
           [ "status" .= statusCode status
           , "size" .= responseSize
           , "body" .=
             if statusCode status >= 400
               then Just .
                    decodeUtf8With lenientDecode .
                    toStrict . BB.toLazyByteString $
                    response
               else Nothing
           ]
       , "time" .= decodeUtf8With lenientDecode date
       ]) <>
  "\n"

requestToJSON :: Request -> [S8.ByteString] -> Maybe NominalDiffTime -> Value
requestToJSON req reqBody duration =
  object $
  [ "method" .= decodeUtf8With lenientDecode (requestMethod req)
  , "path" .= decodeUtf8With lenientDecode (rawPathInfo req)
  , "queryString" .= map queryItemToJSON (queryString req)
  , "size" .= requestBodyLengthToJSON (requestBodyLength req)
  , "body" .= decodeUtf8With lenientDecode (S8.concat reqBody)
  , "remoteHost" .= sockToJSON (remoteHost req)
  , "httpVersion" .= httpVersionToJSON (httpVersion req)
      -- , "headers" .= requestHeadersToJSON (requestHeaders req)
  ] <>
  maybeToList
    (("durationMs" .=) .
     readAsDouble . printf "%.2f" . rationalToDouble . (* 1000) . toRational <$>
     duration)
  where
    rationalToDouble :: Rational -> Double
    rationalToDouble = fromRational

readAsDouble :: String -> Double
readAsDouble = read

queryItemToJSON :: QueryItem -> Value
queryItemToJSON (name, mValue) =
  toJSON
    ( decodeUtf8With lenientDecode name
    , fmap (decodeUtf8With lenientDecode) mValue)

word32ToHostAddress :: Word32 -> Text
word32ToHostAddress = T.intercalate "." . map (T.pack . show) . fromIPv4 . fromHostAddress

sockToJSON :: SockAddr -> Value
sockToJSON (SockAddrInet pn ha) =
  object ["port" .= portToJSON pn, "hostAddress" .= word32ToHostAddress ha]
sockToJSON (SockAddrInet6 pn _ ha _) =
  object ["port" .= portToJSON pn, "hostAddress" .= ha]
sockToJSON (SockAddrUnix sock) =
  object ["unix" .= sock]
sockToJSON _ =
  object ["unknownSock" .= True]

portToJSON :: PortNumber -> Value
portToJSON = toJSON . toInteger

httpVersionToJSON :: HttpVersion -> Value
httpVersionToJSON (HttpVersion major minor) = String $ T.pack (show major) <> "." <> T.pack (show minor)

requestBodyLengthToJSON :: RequestBodyLength -> Value
requestBodyLengthToJSON ChunkedBody     = String "Unknown"
requestBodyLengthToJSON (KnownLength l) = toJSON l