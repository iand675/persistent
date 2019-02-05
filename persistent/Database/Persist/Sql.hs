{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
module Database.Persist.Sql
    ( module Database.Persist.Sql.Types
    , module Database.Persist.Sql.Class
    , module Database.Persist.Sql.Run
    , module Database.Persist.Sql.Migration
    , module Database.Persist
    , module Database.Persist.Sql.Orphan.PersistStore
    , rawQuery
    , rawQueryRes
    , rawExecute
    , rawExecuteCount
    , rawSql
    , deleteWhereCount
    , updateWhereCount
    , transactionSave
    , transactionSaveWithIsolation
    , transactionUndo
    , transactionUndoWithIsolation
    , IsolationLevel (..)
    , getStmtConn
      -- * Internal
    , module Database.Persist.Sql.Internal
    , decorateSQLWithLimitOffset
    ) where

import Database.Persist
import Database.Persist.Sql.Types
import Database.Persist.Sql.Types.Internal (IsolationLevel (..))
import Database.Persist.Sql.Class
import Database.Persist.Sql.Run hiding (withResourceTimeout)
import Database.Persist.Sql.Raw
import Database.Persist.Sql.Migration
import Database.Persist.Sql.Internal

import Database.Persist.Sql.Orphan.PersistQuery
import Database.Persist.Sql.Orphan.PersistStore
import Database.Persist.Sql.Orphan.PersistUnique ()
import Control.Monad.IO.Class

-- | Commit the current transaction and begin a new one.
--
-- @since 1.2.0
transactionSave :: (MonadBackend m, Backend m ~ backend, BaseBackend backend ~ SqlBackend, HasPersistBackend backend, SqlBackendCanWrite backend) => m ()
transactionSave = do
    conn <- persistBackend <$> askBackend
    let getter = getStmtConn conn
    liftIO $ connCommit conn getter >> connBegin conn getter Nothing

-- | Commit the current transaction and begin a new one with the specified isolation level.
--
-- @since 2.9.0
transactionSaveWithIsolation :: (MonadBackend m, Backend m ~ backend, BaseBackend backend ~ SqlBackend, HasPersistBackend backend, SqlBackendCanWrite backend) => IsolationLevel -> m ()
transactionSaveWithIsolation isolation = do
    conn <- persistBackend <$> askBackend
    let getter = getStmtConn conn
    liftIO $ connCommit conn getter >> connBegin conn getter (Just isolation)

-- | Roll back the current transaction and begin a new one.
--
-- @since 1.2.0
transactionUndo :: (MonadBackend m, Backend m ~ backend, BaseBackend backend ~ SqlBackend, HasPersistBackend backend, SqlBackendCanWrite backend) => m ()
transactionUndo = do
    conn <- persistBackend <$> askBackend
    let getter = getStmtConn conn
    liftIO $ connRollback conn getter >> connBegin conn getter Nothing

-- | Roll back the current transaction and begin a new one with the specified isolation level.
--
-- @since 2.9.0
transactionUndoWithIsolation :: (MonadBackend m, Backend m ~ backend, BaseBackend backend ~ SqlBackend, HasPersistBackend backend, SqlBackendCanWrite backend) => IsolationLevel -> m ()
transactionUndoWithIsolation isolation = do
    conn <- persistBackend <$> askBackend
    let getter = getStmtConn conn
    liftIO $ connRollback conn getter >> connBegin conn getter (Just isolation)
