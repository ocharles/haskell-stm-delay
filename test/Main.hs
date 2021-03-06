{-# LANGUAGE CPP #-}

import Control.Concurrent
import Control.Concurrent.STM
import Control.Concurrent.STM.Delay

main = trivial

trivial = do
    let new t = do
            delay <- newDelay t
            return (delay, atomically $ tryWaitDelay delay)

    -- The delay times out at the right time, and after tryWaitDelay returns
    -- 'True', 'updateDelay' and 'cancelDelay' have no observable effect.
    (delay, wait) <- new 100000
    False <- wait
    threadDelay 50000
    False <- wait
    threadDelay 60000
    True <- wait
    updateDelay delay 1000000
    True <- wait
    updateDelay delay (-1)
    True <- wait
    cancelDelay delay
    True <- wait

    (delay, wait) <- new 100000
    False <- wait
    threadDelay 50000
    False <- wait
    updateDelay delay 200000
    threadDelay 60000
    False <- wait
    threadDelay 60000
    False <- wait   -- updateDelay sets the timer based on the current time,
                    -- so the threadDelay 50000 doesn't count toward our total.
    threadDelay 81000
    True <- wait

    -- 'newDelay n' where n <= 0 times out immediately,
    -- rather than never timing out.
    (delay, wait) <- new 0
    threadDelay 100
    True <- wait
    (delay, wait) <- new (-1)
    threadDelay 100
    True <- wait

    -- This fails on Windows without -threaded, as 'threadDelay minBound'
    -- blocks.  It also fails on Linux using GHC 7.0.3 without -threaded.
#if !mingw32_HOST_OS && MIN_VERSION_base(4,4,0)
    (delay, wait) <- new minBound
    threadDelay 1000
    True <- wait
#endif

    -- 'newDelay maxBound' doesn't time out any time soon,
    -- and updateDelay doesn't wait for the delay to complete.
    --
    -- Using maxBound currently fails on Linux 64-bit (see GHC ticket #7325),
    -- so use a more lenient value for now.
    --
    -- (delay, wait) <- new maxBound
    (delay, wait) <- new 2147483647
    False <- wait
    threadDelay 100000
    False <- wait
    updateDelay delay 100000
    threadDelay 90000
    False <- wait
    threadDelay 10010
    True <- wait

    -- cancelDelay causes the delay to miss its initial deadline,
    -- and a subsequent updateDelay has no effect.
    (delay, wait) <- new 100000
    False <- wait
    threadDelay 50000
    False <- wait
    cancelDelay delay
    False <- wait
    threadDelay 60000
    False <- wait
    updateDelay delay 10000
    False <- wait
    threadDelay 20000
    False <- wait
    cancelDelay delay
    False <- wait
    threadDelay 100000
    False <- wait

    return ()
