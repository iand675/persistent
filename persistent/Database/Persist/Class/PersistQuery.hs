{-# LANGUAGE CPP #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts #-}
module Database.Persist.Class.PersistQuery
    ( PersistQueryRead (..)
    , PersistQueryWrite (..)
    , selectSource
    , selectKeys
    , selectList
    , selectKeysList
    ) where

import Database.Persist.Types
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Reader   (ReaderT, MonadReader)

import Data.Conduit (ConduitM, (.|), await, runConduit)
import qualified Data.Conduit.List as CL
import Database.Persist.Class.PersistStore
import Database.Persist.Class.PersistEntity
import Control.Monad.Trans.Resource (MonadResource, release)
import Data.Acquire (Acquire, allocateAcquire, with)

-- | Backends supporting conditional read operations.
class (PersistCore backend, PersistStoreRead backend) => PersistQueryRead backend where
    -- | Get all records matching the given criterion in the specified order.
    -- Returns also the identifiers.
    selectSourceRes
           :: (PersistRecordBackend record backend, MonadIO m2, MonadBackend m1, Backend m1 ~ backend)
           => [Filter record]
           -> [SelectOpt record]
           -> m1 (Acquire (ConduitM () (Entity record) m2 ()))

    -- | Get just the first record for the criterion.
    selectFirst :: (MonadIO m, MonadBackend m, Backend m ~ backend, PersistRecordBackend record backend)
                => [Filter record]
                -> [SelectOpt record]
                -> m (Maybe (Entity record))
    selectFirst filts opts = do
        srcRes <- selectSourceRes filts (LimitTo 1 : opts)
        liftIO $ with srcRes (\src -> runConduit $ src .| await)

    -- | Get the 'Key's of all records matching the given criterion.
    selectKeysRes
        :: (MonadIO m2, MonadBackend m1, Backend m1 ~ backend, PersistRecordBackend record backend)
        => [Filter record]
        -> [SelectOpt record]
        -> m1 (Acquire (ConduitM () (Key record) m2 ()))

    -- | The total number of records fulfilling the given criterion.
    count :: (MonadBackend m, Backend m ~ backend, PersistRecordBackend record backend)
          => [Filter record] -> m Int

-- | Backends supporting conditional write operations
class (PersistQueryRead backend, PersistStoreWrite backend) => PersistQueryWrite backend where
    -- | Update individual fields on any record matching the given criterion.
    updateWhere :: (MonadBackend m, Backend m ~ backend, PersistRecordBackend record backend)
                => [Filter record] -> [Update record] -> m ()

    -- | Delete all records matching the given criterion.
    deleteWhere :: (MonadBackend m, Backend m ~ backend, PersistRecordBackend record backend)
                => [Filter record] -> m ()

-- | Get all records matching the given criterion in the specified order.
-- Returns also the identifiers.
selectSource
       :: (MonadBackend m, Backend m ~ backend, PersistQueryRead (BaseBackend backend),
           MonadResource m, PersistEntity record, PersistEntityBackend record ~ BaseBackend (BaseBackend backend),
           HasPersistBackend backend, HasPersistBackend (BaseBackend backend))
       => [Filter record]
       -> [SelectOpt record]
       -> ConduitM () (Entity record) m ()
selectSource filts opts = do
    srcRes <- liftPersist $ selectSourceRes filts opts
    (releaseKey, src) <- allocateAcquire srcRes
    src
    release releaseKey

-- | Get the 'Key's of all records matching the given criterion.
selectKeys :: (MonadBackend m, Backend m ~ backend, PersistQueryRead (BaseBackend backend), MonadResource m, PersistEntity record, BaseBackend (BaseBackend backend) ~ PersistEntityBackend record, HasPersistBackend backend, HasPersistBackend (BaseBackend backend))
           => [Filter record]
           -> [SelectOpt record]
           -> ConduitM () (Key record) m ()
selectKeys filts opts = do
    srcRes <- liftPersist $ selectKeysRes filts opts
    (releaseKey, src) <- allocateAcquire srcRes
    src
    release releaseKey

-- | Call 'selectSource' but return the result as a list.
selectList :: (MonadBackend m, Backend m ~ backend, PersistQueryRead backend, PersistRecordBackend record backend)
           => [Filter record]
           -> [SelectOpt record]
           -> m [Entity record]
selectList filts opts = do
    srcRes <- selectSourceRes filts opts
    liftIO $ with srcRes (\src -> runConduit $ src .| CL.consume)

-- | Call 'selectKeys' but return the result as a list.
selectKeysList :: (MonadBackend m, Backend m ~ backend, PersistQueryRead backend, PersistRecordBackend record backend)
               => [Filter record]
               -> [SelectOpt record]
               -> m [Key record]
selectKeysList filts opts = do
    srcRes <- selectKeysRes filts opts
    liftIO $ with srcRes (\src -> runConduit $ src .| CL.consume)
