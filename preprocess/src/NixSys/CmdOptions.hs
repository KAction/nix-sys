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

data CmdOptions = CmdOptions
  { -- It would be much simpler to just read from stdin, but ghci does not
    -- support stream redirecting, so I introduce this parameter solely to
    -- make my development more pleasant. It sucks, I know.
    manifestFile :: FilePath,
    -- Path to write config.h
    outputConfig :: FilePath
    --     -- Path where database will be finally installed (probably $cdb output)
    --     finalCDB :: FilePath,
    --     -- Path to write constant database.
    --     outputCDB :: f FilePath
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
      )

ioCmdOptions :: IO CmdOptions
ioCmdOptions = execParser opts
  where
    opts =
      info
        (cmdOptions <**> helper)
        (fullDesc <> progDesc "preprocess nix-sys manifest")
