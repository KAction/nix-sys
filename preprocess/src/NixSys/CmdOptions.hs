{-# LANGUAGE TypeFamilies #-}

module NixSys.CmdOptions where

import Options.Applicative
  ( Parser,
    execParser,
    fullDesc,
    help,
    helper,
    info,
    long,
    metavar,
    progDesc,
    showDefault,
    strOption,
    value,
    (<**>),
  )
import Data.Text (Text)

data CmdOptions = CmdOptions
  { -- It would be much simpler to just read from stdin, but ghci does not
    -- support stream redirecting, so I introduce this parameter solely to
    -- make my development more pleasant. It sucks, I know.
    manifestFile :: FilePath,
    -- Path to write config.h
    outputConfig :: FilePath,
    -- Path where database will be finally installed (probably $cdb output)
    installCDB :: FilePath,
    -- Path to write constant database.
    outputCDB :: FilePath,
    hash :: Text
  }

cmdOptions :: Parser CmdOptions
cmdOptions =
  CmdOptions
    <$> strOption
      ( long "manifest-file"
          <> metavar "FILE"
          <> help "source file of manifest in json format"
          <> value "/dev/stdin"
          <> showDefault
      )
    <*> strOption
      ( long "output-config"
          <> metavar "FILE"
          <> help "path to write output config.h"
          <> value "/dev/stdout"
          <> showDefault
      )
    <*> strOption
      ( long "install-cdb"
          <> metavar "FILE"
          <> help "installation path of cdb database"
      )
    <*> strOption
      ( long "output-cdb"
          <> metavar "FILE"
          <> help "path to write output cdb database"
          <> value "out.cdb"
          <> showDefault
      )
    <*> strOption
      ( long "hash" <> help "hash of nix-sys output path")

ioCmdOptions :: IO CmdOptions
ioCmdOptions = execParser opts
  where
    opts =
      info
        (cmdOptions <**> helper)
        (fullDesc <> progDesc "preprocess nix-sys manifest")
