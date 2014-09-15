{-# OPTIONS_GHC -fno-warn-unused-binds -fno-warn-orphans #-}
{-# LANGUAGE QuasiQuotes, TemplateHaskell, CPP, GADTs, TypeFamilies, OverloadedStrings, FlexibleContexts, EmptyDataDecls, FlexibleInstances, GeneralizedNewtypeDeriving #-}
module RenameTest (specs) where

import Database.Persist.Sqlite
#ifndef WITH_MONGODB
import Data.Time (Day)
import qualified Data.Conduit as C
import qualified Data.Conduit.List as CL
import Control.Monad.Trans.Resource (runResourceT)
#endif
import qualified Data.Map as Map
import qualified Data.Text as T
import Data.Aeson

import Init

instance ToJSON Day   where toJSON    = error "Day.toJSON"
instance FromJSON Day where parseJSON = error "Day.parseJSON"

-- persistent used to not allow types with an "Id" suffix
type TextId = Text

-- Test lower case names
#if WITH_MONGODB
mkPersist persistSettings [persistUpperCase|
#else
share [mkPersist sqlSettings, mkMigrate "lowerCaseMigrate"] [persistLowerCase|
#endif
IdTable
    Id   Day default=CURRENT_DATE
    name Text
    deriving Eq Show
LowerCaseTable
    Id            sql=my_id
    fullName Text
    ExtraBlock
        foo bar
        baz
        bin
    ExtraBlock2
        something
RefTable
    someVal Int sql=something_else
    lct LowerCaseTableId
    text TextId
    UniqueRefTable someVal
|]

specs :: Spec
specs = describe "rename specs" $ do
#ifndef WITH_MONGODB
    it "handles lower casing" $ asIO $
        runConn $ do
            _ <- runMigration lowerCaseMigrate
            runResourceT $ rawQuery "SELECT full_name from lower_case_table WHERE my_id=5" [] C.$$ CL.sinkNull
            runResourceT $ rawQuery "SELECT something_else from ref_table WHERE id=4" [] C.$$ CL.sinkNull
#endif

#ifndef WITH_POSTGRESQL
    it "user specified id" $ db $ do
      let rec = IdTable "Foo"
      k <- insert rec
      Just rec' <- get k
      rec' @== rec
#endif

    it "extra blocks" $
        entityExtra (entityDef (Nothing :: Maybe LowerCaseTable)) @?=
            Map.fromList
                [ ("ExtraBlock", map T.words ["foo bar", "baz", "bin"])
                , ("ExtraBlock2", map T.words ["something"])
                ]

asIO :: IO a -> IO a
asIO = id
