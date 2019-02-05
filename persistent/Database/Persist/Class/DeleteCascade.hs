{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Database.Persist.Class.DeleteCascade
    ( DeleteCascade (..)
    , deleteCascadeWhere
    ) where

import Database.Persist.Class.PersistStore
import Database.Persist.Class.PersistQuery
import Database.Persist.Class.PersistEntity

import Data.Conduit
import qualified Data.Conduit.List as CL
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Reader (ReaderT, ask, runReaderT)
import Data.Acquire (with)

-- | For combinations of backends and entities that support
-- cascade-deletion. “Cascade-deletion” means that entries that depend on
-- other entries to be deleted will be deleted as well.
class (PersistStoreWrite backend, PersistEntity record, BaseBackend backend ~ PersistEntityBackend record)
  => DeleteCascade record backend where

    -- | Perform cascade-deletion of single database
    -- entry.
    deleteCascade :: (MonadBackend m, Backend m ~ backend) => Key record -> m ()

-- | Cascade-deletion of entries satisfying given filters.
deleteCascadeWhere :: (MonadBackend m, Backend m ~ backend, DeleteCascade record backend, PersistQueryWrite backend)
                   => [Filter record] -> m ()
deleteCascadeWhere filts = do
    srcRes <- selectKeysRes filts []
    conn <- askBackend
    liftIO $ with srcRes (\src -> runConduit $ src .| CL.mapM_ (flip runReaderT conn . deleteCascade))
