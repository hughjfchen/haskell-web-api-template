{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators     #-}
module Domain.API.User
  (server, UserAPI, userAPI, newRepo)
where

import           Import
import           Domain.Types
import           Servant
import qualified Data.HashMap.Strict as B

type UserAPI = "users" :> Get '[JSON] [User]

userAPI :: Proxy UserAPI
userAPI = Proxy

-- server :: Server UserAPI
server :: App [User]
server = getUsers

type UserRepo = TVar (HashMap Text User)

newRepo :: IO UserRepo
newRepo = atomically (newTVar users)
  where
    users = B.fromList defaultUsers

defaultUsers :: [(Text, User)]
defaultUsers = [("1234", User (Name "name1") (Email "email@test.com"))]

getUsers :: App [User]
getUsers = do
  logWarn "Fetching users from db"
  logInfoS "some inner func" "Fetching users from db"
  return $ [User (Name "name1") (Email "email@test.com")]