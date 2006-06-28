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
   Module     : Main
   Copyright  : Copyright (C) 2006 John Goerzen
   License    : GNU GPL, version 2 or above

   Maintainer : John Goerzen <jgoerzen@complete.org>
   Stability  : provisional
   Portability: portable

Written by John Goerzen, jgoerzen\@complete.org

-}

import Config
import DB
import MissingH.Logging.Logger
import MissingH.GetOpt
import System.Console.GetOpt
import System.Environment
import Data.List
import System.Exit
import Commands
import Types
import Control.Monad

main = 
    do updateGlobalLogger "" (setLevel DEBUG)
       infoM "" " - - - hspod - - -"
       argv <- getArgs
       let (optargs, commandargs) = span (isPrefixOf "-") argv
       case getOpt RequireOrder options optargs of
         (o, n, []) -> worker o n commandargs
         (_, _, errors) -> usageerror (concat errors) -- ++ usageInfo header options)
       infoM "" "Done."

       
options = [Option "d" ["debug"] (NoArg ("d", "")) "Enable debugging",
           Option "" ["help"] (NoArg ("help", "")) "Display this help"]

worker args n commandargs =
    do when (lookup "help" args == Just "") $ usageerror ""
       let commandname = head cmdargs
       case lookup commandname allCommands of
         Just command -> execcmd command (tail cmdargs)
         Nothing -> usageerror ("Invalid command name " ++ commandname)
       where cmdargs = case commandargs of
                         [] -> ["fake"]
                         x -> x

usageerror errormsg =
    do putStrLn errormsg
       putStrLn (usageInfo header options)
       exitFailure

header = "Usage: hspod [global-options] command [command-options]\n\n\
         \Run hspod lscommands for information on the available commands.\n\
         \\n\
         \Available global-options are:\n"