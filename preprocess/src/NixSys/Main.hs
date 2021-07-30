{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralisedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}

module NixSys.Main where

import Control.Monad (join)
import Data.Aeson (ToJSON (..), Value (..), eitherDecodeFileStrict, object)
import Data.Coerce (coerce)
import qualified Data.HashMap.Strict as HashMap
import Data.List (inits)
import Data.Map (Map)
import qualified Data.Map as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy.IO as TIO
import qualified Data.Vector as Vector
import NixSys.CmdOptions (CmdOptions (..), ioCmdOptions)
import NixSys.Parser (Location (..), Spec (..))
import System.Exit (exitFailure)
import Text.Mustache (renderMustache)
import Text.Mustache.Compile.TH (compileMustacheFile)

-- Return sorted list of parent directories of spec targets, so nix-sys
-- do not need to do string manipulation in C.
parents :: Spec -> [Text]
parents s =
  let locations =
        coerce $
          Map.keys (copy s)
            ++ Map.keys (mkdir s)
            ++ Map.keys (symlink s)
      parents1 :: Text -> [Text]
      parents1 = map (T.intercalate "/") . inits . T.splitOn "/"

      sortAsc :: Ord a => [a] -> [a]
      sortAsc = Set.toList . Set.fromList
   in sortAsc . filter (/= "") . join . map parents1 $ locations

-- Mustache does not support iterating over dictionary keys, only over
-- list elements, but 'Spec' datatype uses dictionary instead of list to
-- make some incoherent manifests unrepresentable.
--
-- So here we convert it dictionary with variable keys into the list.
-- This function uses partial functions to avoid a lot of boilerplate,
-- but is total by itself.
specToContext :: Spec -> Text -> Value
specToContext s hash =
  object
    [ ("copy", fromMap (copy s)),
      ("mkdir", fromMap (mkdir s)),
      ("symlink", fromMap (symlink s)),
      ("exec", maybe Null locToString (exec s)),
      ("parents", Array . Vector.fromList . map String . parents $ s)
    ]
  where
    locToString :: Location -> Value
    locToString (Location e) = String e

    fromMap :: (ToJSON a) => Map Location a -> Value
    fromMap = Array . Vector.fromList . map f . Map.toList

    f :: ToJSON a => (Location, a) -> Value
    f (Location target, a) =
      let Object m = toJSON a -- partial
       in Object
            . HashMap.insert "target" (String target)
            . HashMap.insert "hash" (String hash)
            $ m

main :: IO ()
main = do
  CmdOptions {..} <- ioCmdOptions
  spec <-
    eitherDecodeFileStrict manifestFile >>= \case
      Left err -> putStrLn err >> exitFailure
      Right a -> pure a
  let template = $(compileMustacheFile "./data/config.h.mustache")
  TIO.writeFile outputConfig $
    renderMustache template (specToContext spec "foo")
