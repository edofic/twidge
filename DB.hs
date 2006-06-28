{- hspod component
Copyright (C) 2006 John Goerzen <jgoerzen@complete.org>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- |
   Module     : DB
   Copyright  : Copyright (C) 2006 John Goerzen
   License    : GNU GPL, version 2 or above

   Maintainer : John Goerzen <jgoerzen@complete.org>
   Stability  : provisional
   Portability: portable

Written by John Goerzen, jgoerzen\@complete.org

-}
module DB where
import Config
import Types

import Database.HDBC
import Database.HDBC.Sqlite3
import MissingH.Logging.Logger
import Control.Monad

connect :: IO Connection
connect = handleSqlError $
    do fp <- getDBName
       connectSqlite3 fp
       dbh <- connectSqlite3 fp
       prepDB dbh
       return dbh

prepDB dbh =
    do tables <- getTables dbh
       schemaver <- prepSchema dbh tables
       upgradeSchema dbh schemaver tables

prepSchema :: Connection -> [String] -> IO Int
prepSchema dbh tables =
    if "schemaver" `elem` tables
       then do r <- quickQuery dbh "SELECT version FROM schemaver" []
               case r of
                 [[x]] -> return (fromSql x)
                 x -> fail $ "Unexpected result in prepSchema: " ++ show x
       else do run dbh "CREATE TABLE schemaver (version INTEGER)" []
               run dbh "INSERT INTO schemaver VALUES (0)" []
               commit dbh
               return 0

upgradeSchema _ 1 _ = return ()
upgradeSchema dbh 0 tables =
    do debugM "DB" "Upgrading schema 0 -> 1"
       unless ("podcasts" `elem` tables)
              (run dbh "CREATE TABLE podcasts(\
                       \castid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\
                       \castname TEXT NOT NULL,\
                       \feedurl TEXT NOT NULL UNIQUE)" [] >> return ())
       unless ("episodes" `elem` tables)
              (run dbh "CREATE TABLE episodes (\
                       \castid INTEGER NOT NULL, \
                       \title TEXT NOT NULL, \
                       \epurl TEXT NOT NULL, \
                       \status TEXT NOT NULL,\
                       \PRIMARY KEY(castid, epurl) )" [] >> return ())
       run dbh "DELETE FROM schemaver" []
       run dbh "INSERT INTO schemaver VALUES (1)" []
       commit dbh

{- | Adds a new podcast to the database.  Ignores the castid on the incoming
podcast, and returns a new object with the castid populated. -}
addPodcast :: Connection -> Podcast -> IO Podcast
addPodcast dbh podcast =
    do run dbh "INSERT INTO podcasts (castname, feedurl) VALUES (?, ?)"
           [toSql (castname podcast), toSql (feedurl podcast)]
       r <- quickQuery dbh "SELECT castid FROM podcasts WHERE feedurl = ?"
            [toSql (feedurl podcast)]
       case r of
         [[x]] -> return $ podcast {castid = fromSql x}
         y -> fail $ "Unexpected result: " ++ show y

updatePodcast :: Connection -> Podcast -> IO ()
updatePodcast dbh podcast = 
    run dbh "UPDATE podcasts SET castname = ?, feedurl = ? WHERE castid = ?"
        [toSql (castname podcast), toSql (feedurl podcast),
         toSql (castid podcast)] >> return ()
