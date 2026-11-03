{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}

module CoreTests.TransportServerTests where

import Control.Concurrent.STM (newEmptyTMVarIO)
import Control.Exception (bracket)
import Network.Socket
import Simplex.Messaging.Transport.Server (startTCPServer)
import Test.Hspec hiding (fit, it)
import Util
#if !defined(mingw32_HOST_OS)
import Control.Concurrent (runInBoundThread)
import Control.Exception (bracket_)
import Foreign.C.Types (CInt (..))

foreign import ccall unsafe "set_ipv6_unsupported" setIPv6Unsupported :: CInt -> IO ()
#endif

transportServerTests :: Spec
transportServerTests = do
  it "should listen on IPv6 wildcard address" $
    wildcardAddress `shouldReturn` SockAddrInet6 0 0 (0, 0, 0, 0) 0
#if !defined(mingw32_HOST_OS)
  it "should listen on IPv4 wildcard address when IPv6 is not supported" $
    runInBoundThread $
      bracket_ (setIPv6Unsupported 1) (setIPv6Unsupported 0) $
        wildcardAddress `shouldReturn` SockAddrInet 0 0
#endif

wildcardAddress :: IO SockAddr
wildcardAddress = do
  started <- newEmptyTMVarIO
  bracket (startTCPServer started Nothing "0") close $ fmap anyPort . getSocketName
  where
    anyPort = \case
      SockAddrInet _ h -> SockAddrInet 0 h
      SockAddrInet6 _ f h s -> SockAddrInet6 0 f h s
      a -> a
