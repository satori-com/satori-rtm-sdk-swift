#!/usr/bin/env stack
-- stack --resolver nightly-2017-09-25 script --package text --package shake --package extra --package bytestring --package aeson --package process

{-# language DeriveGeneric #-}
{-# language LambdaCase #-}
{-# language ViewPatterns #-}

import Control.Monad
import Data.Aeson
import qualified Data.ByteString.Lazy as BSL
import Data.Function ((&))
import Data.List.Extra
import Data.List (intercalate)
import Data.Monoid
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import GHC.Generics
import System.Directory.Extra
import System.Exit
import System.Process
import System.Process.Extra
import System.Timeout

import Development.Shake
import Development.Shake.FilePath

tutorialExe :: String
tutorialExe = ".test_tutorial/.build/debug/Tutorial"

tutorialSourceFiles :: [String]
tutorialSourceFiles = ["Tutorials/Sources/Quickstart/main.swift"]

main :: IO ()
main = shakeArgs shakeOptions {shakeFiles = ".shake"} $ do
    sourceFiles <- liftIO $ listContents "Sources"
    exampleNames <- liftIO $ fmap (map (drop (length "examples/Sources/"))) $ listContents "examples/Sources"

    want ["test"]

    phony "test" $ do
        need ["credentials.json"]
        cmd Shell "swift test --parallel || swift test"

    "SatoriRTM.xcodeproj/project.pbxproj" %> \_out -> do
        need ["Package.swift"]
        need sourceFiles
        cmd "swift package generate-xcodeproj"

    phony "xcodeproj" $ need ["SatoriRTM.xcodeproj/project.pbxproj"]

    phony "build" $ cmd "swift build"

    phony "lint" $ do
        Exit c <- cmd "rg ! Sources"
        case c of
            ExitSuccess -> fail "Every bang is a potential segfault!"
            _ -> liftIO $ putStrLn "Linters are happy"
        cmd_ "swiftlint lint"
        cmd "tailor Sources"

    phony "docs" $ need ["docs/index.html"]

    "SatoriRTM.xcworkspace/contents.xcworkspacedata" %> \out -> do
        liftIO $ TIO.writeFile out $ T.pack $ unlines
            [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
            , "<Workspace version = \"1.0\">"
            , "      <FileRef location = \"group:SatoriRTM.xcodeproj\"></FileRef>"
            , "</Workspace>"
            ]

    "docs/index.html" %> \_ -> do
        need ["SatoriRTM.xcodeproj/project.pbxproj"]
        need ["SatoriRTM.xcworkspace/contents.xcworkspacedata"]
        need sourceFiles
        cmd_ "jazzy --clean --xcodebuild-arguments -workspace,SatoriRTM.xcworkspace --xcodebuild-arguments -scheme,SatoriRTM-Package --exclude Sources/RTMConnection*.swift --theme fullwidth"
        cmd_ "rm -rf docs/docsets"

    phony "build-tutorial" $ need [tutorialExe]

    tutorialExe %> \_ -> do
        need sourceFiles
        need tutorialSourceFiles
        need ["credentials.json"]
        cmd_ Shell "rm -rf .test_tutorial; mkdir -p .test_tutorial/Sources/Tutorial; mkdir -p .test_tutorial/Sources/SatoriRTM"
        cmd_ Shell "cp Sources/*.swift .test_tutorial/Sources/SatoriRTM/"
        traced "Injecting credentials" $ injectCredentials "Tutorials/Sources/Quickstart/main.swift" ".test_tutorial/Sources/Tutorial/main.swift"
        traced "Writing Package.swift" $ TIO.writeFile ".test_tutorial/Package.swift" $ T.pack $ unlines
            [ "import PackageDescription"
            , "let package = Package(name: \"tutorial\","
            , "targets: ["
            , "  Target(name: \"SatoriRTM\"),"
            , "  Target(name: \"Tutorial\", dependencies: [\"SatoriRTM\"]),"
            , "],"
            , "dependencies: ["
            , "  .Package(url: \"https://github.com/daltoniam/Starscream.git\", Version(2,0,4)),"
            , "  .Package(url: \"https://github.com/IBM-Swift/CommonCrypto.git\", majorVersion: 0),"
            , "  .Package(url: \"https://github.com/SwiftyBeaver/SwiftyBeaver.git\", majorVersion: 1)"
            , "])"
            ]
        cmd Shell "cd .test_tutorial && swift build -Xswiftc \"-target\" -Xswiftc \"x86_64-apple-macosx10.12\""

    phony "debug-tutorial" $ do
        need [tutorialExe]
        cmd_ tutorialExe

    phony "run-tutorial" $ do
        need [tutorialExe]
        let runTutorial = readProcessWithExitCode tutorialExe [] ""
        tutorialResult <- liftIO (timeout (10 * 1000 * 1000) runTutorial)
        case tutorialResult of
            Just (code, out, err) -> liftIO $ do
                putStrLn $ "Tutorial finished prematurely with code " <> show code
                putStrLn out
                putStrLn err
                error "tutorial failed"
            Nothing -> liftIO $ putStrLn "Tutorial seems to be working fine"

    phony "build-examples" $
        need [".test_examples/.build/debug" </> name | name <- exampleNames]

    [".test_examples/.build/debug" </> name | name <- exampleNames] &%> \_ -> do
        need sourceFiles
        need ["Examples/Sources" </> name </> "main.swift" | name <- exampleNames]
        need ["credentials.json"]
        cmd_ Shell "rm -rf .test_examples; mkdir -p .test_examples/Sources/SatoriRTM"
        cmd_ Shell "cp Sources/*.swift .test_examples/Sources/SatoriRTM/"
        forM_ exampleNames $ \name -> do
            cmd_ "mkdir" (".test_examples/Sources" </> name)
            liftIO $ injectCredentials
                ("examples/Sources" </> name </> "main.swift")
                (".test_examples/Sources" </> name </> "main.swift")
        liftIO $ TIO.writeFile ".test_examples/Package.swift" $ T.pack $ unlines $
            [ "import PackageDescription"
            , "let package = Package(name: \"examples\","
            , "targets: ["
            , "  Target(name: \"SatoriRTM\"),"
            ] ++ ["  Target(name: \"" <> name <> "\", dependencies: [\"SatoriRTM\"])," | name <- exampleNames] ++
            [ "],"
            , "dependencies: ["
            , "  .Package(url: \"https://github.com/daltoniam/Starscream.git\", Version(2,0,4)),"
            , "  .Package(url: \"https://github.com/IBM-Swift/CommonCrypto.git\", majorVersion: 0),"
            , "  .Package(url: \"https://github.com/SwiftyBeaver/SwiftyBeaver.git\", majorVersion: 1)"
            , "])"
            ]
        cmd Shell "cd .test_examples && swift build"

    phony "run-examples" $ do
        need ["build-examples"]
        let examplesThatShouldFinish = ["Connect", "Authenticate"]
        forM_ exampleNames $ \name -> do
            let runExample = readProcessWithExitCode (".test_examples/.build/debug/" <> name) [] ""
            result <- liftIO (timeout (10 * 1000 * 1000) runExample)
            case (result, name `elem` examplesThatShouldFinish) of
                (Just (code, out, err), False) -> liftIO $ do
                    putStrLn $ name <> " finished prematurely with code " <> show code
                    putStrLn out
                    putStrLn err
                    liftIO $ fail (name <> " failed")
                (Nothing, False) -> liftIO $ putStrLn ("Example " <> name <> " seems to be working fine")
                (Just (ExitSuccess, _, _), True) -> liftIO $ putStrLn ("Example " <> name <> " seems to be working fine")
                (Nothing, True) -> liftIO $ fail ("Example " <> name <> " should have finished, but did not")

    phonys $ \case
        (splitOn "-" -> ["debug", "example", name]) -> Just $ do
            need ["build-examples"]
            cmd_ (".test_examples/.build/debug/" <> name)
        _ -> Nothing

    phony "enable-symlinks" $ do
        ExitSuccess <- cmd Shell "cd Examples && swift package edit SatoriRTM --path .."
        ExitSuccess <- cmd Shell "cd Tutorials && swift package edit SatoriRTM --path .."
        pure ()

    phony "disable-symlinks" $ do
        ExitSuccess <- cmd Shell "cd Examples && swift package unedit SatoriRTM"
        ExitSuccess <- cmd Shell "cd Tutorials && swift package unedit SatoriRTM"
        pure ()

    phony "clean" $ do
        removeFilesAfter ".shake" ["//*"]
        removeFilesAfter ".test_examples" ["//*"]
        removeFilesAfter ".test_tutorial" ["//*"]

    phony "everything" $ need ["lint", "test", "run-examples", "run-tutorial"]

data Creds = Creds
    { endpoint :: T.Text
    , appkey :: T.Text
    , open_data_appkey :: T.Text
    , auth_role_name :: T.Text
    , auth_role_secret_key :: T.Text
    } deriving Generic

instance FromJSON Creds

injectCredentials :: FilePath -> FilePath -> IO ()
injectCredentials src dst = do
    content <- TIO.readFile src
    Just creds <- decode <$> BSL.readFile "credentials.json"
    let content' = content
            & T.replace (T.pack "YOUR_ENDPOINT") (endpoint creds)
            & T.replace (T.pack "OPEN_DATA_APPKEY") (open_data_appkey creds)
            & T.replace (T.pack "YOUR_APPKEY") (appkey creds)
            & T.replace (T.pack " = \"YOUR_ROLE") (T.pack " = \"" <> auth_role_name creds)
            & T.replace (T.pack "YOUR_SECRET") (auth_role_secret_key creds)
    TIO.writeFile dst content'