{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module NixSys.Parser where

import Control.Applicative ((<|>))
import Control.Monad (unless, when)
import Data.Aeson (withObject, withText, (.:), (.:?), withArray)
import Data.Aeson.TH (Options (..), defaultOptions, deriveToJSON)
import qualified Data.Vector as Vector
import Lens.Micro ((.~), (&), (^.))
import Data.Aeson.Types
  ( FromJSON (..),
    ToJSON (..),
    FromJSONKey (..),
    FromJSONKeyFunction (..),
    Parser,
    Value(String),
  )
import Data.Functor (($>))
import qualified Data.ByteString as ByteString
import Data.ByteString.Lazy (toStrict)
import Data.ByteString.Builder (word8Hex, toLazyByteString)
import qualified System.Capability as Capability
import System.Capability (permitted, inheritable)
import qualified Data.HashMap.Strict as H
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8)
import Data.Word (Word16, Word32)
import Numeric (readOct)

-- Avoiding orphan instances
newtype Wrapped a = Wrapped { unwrapped :: a } deriving (Semigroup, Monoid)

-- Absolute file path. We are not performing any operation on it except
-- validating that it is actually absolute (starts with /).
newtype Location = Location Text deriving (Eq, Ord, Show)
instance Show (Wrapped Capability.File) where
  show (Wrapped f) =
    "Capability.File { permitted = "
      <> show (f^.permitted)
      <> ", inhertiable = "
      <> show (f^.inheritable)
      <> "}"

instance ToJSON (Wrapped Capability.File) where
  toJSON (Wrapped f) =
    let bs = Capability.encode f
        merge a w = a <> "\\x" <> word8Hex w
        escaped = toStrict . toLazyByteString $ "\"" <> ByteString.foldl' merge mempty bs <> "\""
    in String $ if f == mempty then "NULL" else decodeUtf8 escaped

$(deriveToJSON defaultOptions ''Location)

parseLocation :: Text -> Parser Location
parseLocation t = do
  unless (T.isPrefixOf "/" t) $
    fail $ "Location `" <> T.unpack t <> "' is not absolute"
  when (T.isInfixOf "/./" t || T.isInfixOf "/../" t) $
    fail $ "Location `" <> T.unpack t <> "' contains redundant path segments"
  pure $ Location t

instance FromJSON Location where
  parseJSON = withText "Location" parseLocation

instance FromJSONKey Location where
  fromJSONKey = FromJSONKeyTextParser parseLocation

-- Mode of the file. We are not performing any operations on it except
-- substituting it into template, so we do not use more type-safe
-- representation.
newtype Mode = Mode Word16 deriving (Show)

$(deriveToJSON defaultOptions ''Mode)

instance FromJSON Mode where
  parseJSON e = parseText e <|> parseInt e
    where
      parseWord w = do
        unless (w < 07777) $
          fail "Mode value can't be greater than 07777"
        pure $ Mode w
      parseInt v = parseJSON v >>= parseWord
      parseText v = do
        s <- parseJSON v
        case readOct s of
          [(w, "")] -> parseWord w
          _ -> fail "Mode string value does not represent octal value"

-- Specification that file at specified location must be regular file with
-- specified mode, ownership and content copied from another file (presumably
-- in Nix store)
data SpecCopy = SpecCopy
  { path :: Location,
    mode :: Mode,
    owner :: Word32,
    group :: Word32,
    capabilities :: Wrapped Capability.File
  }
  deriving (Show)

$(deriveToJSON (defaultOptions {rejectUnknownFields = True}) ''SpecCopy)

data SpecMkdir = SpecMkdir
  { mode :: Mode,
    owner :: Word32,
    group :: Word32
  }
  deriving (Show)

$(deriveToJSON (defaultOptions {rejectUnknownFields = True}) ''SpecMkdir)

newtype SpecSymlink = SpecSymlink {path :: Location}
  deriving (Show)

checkKnownFields :: H.HashMap Text Value -> [Text] -> Parser ()
checkKnownFields m kf = do
  let known = H.fromList $ map (\x -> (x, ())) kf
      actual = m $> ()
      diff = map fst . H.toList $ H.difference actual known
  unless (null diff) $ do
    fail $ "unknownFields: " ++ show diff

instance FromJSON SpecSymlink where
  parseJSON = withObject "SpecSymlink" $ \o -> do
    checkKnownFields o ["path"]
    SpecSymlink <$> ((o .: "path") >>= parseLocation)

$(deriveToJSON defaultOptions ''SpecSymlink)

data Spec = Spec
  { copy :: Map Location SpecCopy,
    mkdir :: Map Location SpecMkdir,
    symlink :: Map Location SpecSymlink,
    exec :: Maybe Location
  }
  deriving (Show)

instance FromJSON SpecMkdir where
  parseJSON = withObject "SpecMkdir" $ \o -> do
    checkKnownFields o ["mode", "owner", "group"]
    SpecMkdir <$> o .: "mode"
      <*> fmap (fromMaybe 0) (o .:? "owner")
      <*> fmap (fromMaybe 0) (o .:? "group")

-- Parse one bit of capability set from a string
parse1 :: Value -> Parser Capability.Set
parse1 = withText "capability" $ \name -> do
  -- Not strictly necessary, but avoids future style bikeshedding.
  unless (T.toLower name == name) $ do
    fail $ "Capability name `" <> T.unpack name <> "' is not in lower case"

  let name' = "CAP_" <> T.toUpper name
  case lookup name' Capability.known of
    Nothing -> fail $ "Unknown capability name `"<> T.unpack name <> "'"
    Just a -> pure a

instance FromJSON (Wrapped Capability.Set) where
  parseJSON = withArray "Capability.Set" $ \a ->
    Wrapped <$> Vector.foldM (\acc v -> mappend <*> pure acc <$> parse1 v) mempty a

instance FromJSON (Wrapped Capability.File) where
  parseJSON = withObject "Capability.File" $ \o -> do
    checkKnownFields o ["permitted", "inheritable"]
    p <- fmap (unwrapped . fromMaybe mempty) (o .:? "permitted")
    i <- fmap (unwrapped . fromMaybe mempty) (o .:? "inheritable")
    pure . Wrapped $ mempty & permitted .~ p
                            & inheritable .~ i

instance FromJSON SpecCopy where
  parseJSON = withObject "SpecMkdir" $ \o -> do
    checkKnownFields o ["path", "mode", "owner", "group", "capabilities"]
    SpecCopy <$> o .: "path"
      <*> o .: "mode"
      <*> fmap (fromMaybe 0) (o .:? "owner")
      <*> fmap (fromMaybe 0) (o .:? "group")
      <*> fmap (fromMaybe mempty) (o .:? "capabilities")

-- Instance generated by TH makes map fields mandatory. It is possible to make
-- it optional by declaring it (Maybe Map) instead of just Map, but it would
-- require extra processing.
--
-- I prefer to contain as much complexity as possible in the parser. This way I
-- automatically get decent error messages.
instance FromJSON Spec where
  parseJSON = withObject "Spec" $ \o -> do
    checkKnownFields o ["copy", "mkdir", "symlink", "exec"]
    Spec
      <$> fmap (fromMaybe Map.empty) (o .:? "copy")
      <*> fmap (fromMaybe Map.empty) (o .:? "mkdir")
      <*> fmap (fromMaybe Map.empty) (o .:? "symlink")
      <*> o .:? "exec"
