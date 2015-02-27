{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}

-- |
-- Module      : Control.Auto.Blip.Internal
-- Description : Exposing internal unsafe functions for working with
--               'Blip'.
-- Copyright   : (c) Justin Le 2014
-- License     : MIT
-- Maintainer  : justin@jle.im
-- Stability   : unstable
-- Portability : portable
--
-- This module exposes an "unsafe" interface for working with the internal
-- representation of "blip streams".  If you are programming at the logic
-- level or the application level, you should thoroughly be able to avoid
-- importing this, and should be happy with importing the 'Blip' type from
-- "Control.Auto" and blip stream manipulators from "Control.Auto.Blip".
--
-- If, however, you are programming a framework, library, or backend, you
-- might find it useful to manually create your own blip streams/sources.
-- In this case, this module will be useful.
--
-- It is important, as with most of this library in general, to always keep
-- in mind when you are programming at the "logic" level, and when you are
-- programming at the "backend" level.  If you can justify that you are at
-- the backend level and not at the logic level of whatever you are
-- programming, then this is useful.
--
-- Be sure, of course, that whatever 'Blip' streams you do manually
-- construct and export preserve "Blip semantics", which is further
-- defined in "Control.Auto.Blip".
--
-- You have been warned!
--

module Control.Auto.Blip.Internal (
    Blip(..)
  , merge
  , mergeL
  , mergeR
  , blip
  ) where

import Control.DeepSeq
import Data.Semigroup
import Data.Serialize
import Data.Typeable
import GHC.Generics

infixr 5 `mergeL`
infixl 5 `mergeR`

-- | When used in the context of an input or output of an 'Auto', a @'Blip'
-- a@ represents a stream that occasionally, at "independent" or "discrete"
-- points, emits a value of type @a@.
--
-- Contrast this to 'Interval', where things are meant to be "on" or "off"
-- for contiguous chunks at a time; blip streams are "blippy", and
-- 'Interval's are "chunky".
--
-- It's here mainly because it's a pretty useful abstraction in the context
-- of the many combinators found in various modules of this library.  If
-- you think of an @'Auto' m a ('Blip' b)@ as producing a "blip stream",
-- then there are various combinators and functions that are specifically
-- designed to manipulate blip streams.
--
-- For the purposes of the semantics of what 'Blip' is supposed to
-- represent, its constructors are hidden.  (Almost) all of the various
-- 'Blip' combinators (and its very useful 'Functor' instance) "preserve
-- 'Blip'ness" --- one-at-a-time occurrences remain one-at-a-time under all
-- of these combinators, and you should have enough so that direct access
-- to the constructor is not needed.
--
-- If you are creating a framework, library, or backend, you might want to
-- manually create 'Blip' stream-producing 'Auto's for your users to
-- access.  In this case, you can import the constructors and useful
-- internal (and, of course, semantically unsafe) functions from
-- "Control.Auto.Blip.Internal".
data Blip a =  NoBlip
             | Blip !a
             deriving ( Functor
                      , Show
                      , Typeable
                      , Generic
                      )

-- | Merge two blip streams together; the result emits with /either/ of the
-- two merged streams emit.  When both emit at the same time, emit the
-- result of '<>'-ing the values together.
instance Semigroup a => Semigroup (Blip a) where
    (<>) = merge (<>)

-- | Merge two blip streams together; the result emits with /either/ of the
-- two merged streams emit.  When both emit at the same time, emit the
-- result of '<>'-ing the values together.
instance Semigroup a => Monoid (Blip a) where
    mempty  = NoBlip
    mappend = merge (<>)

instance Serialize a => Serialize (Blip a)

-- TODO: Am I allowed to do this?
instance NFData a => NFData (Blip a)

-- | Merge two blip streams together; the result emits with /either/ of the
-- two merged streams emit.  When both emit at the same time, emit the
-- result of applying the given function on the two values.
--
-- Note that this might be too strict for some purposes; see 'mergeL' and
-- 'mergeR' for lazier alternatives.
merge :: (a -> a -> a)      -- ^ merging function
      -> Blip a             -- ^ first stream
      -> Blip a             -- ^ second stream
      -> Blip a             -- ^ merged stream
merge _ ex NoBlip          = ex
merge _ NoBlip ey          = ey
merge f (Blip x) (Blip y) = Blip (f x y)

-- | Merges two 'Blip' streams together into one, which emits
-- /either/ of the original 'Blip' streams emit.  If both emit at the same
-- time, the left (first) one is favored.
--
-- Lazy on the second stream if the first stream is emitting.
--
-- If we discount laziness, this is @'merge' 'const'@.
mergeL :: Blip a -> Blip a -> Blip a
mergeL b1@(Blip _) _  = b1
mergeL _           b2 = b2

-- | Merges two 'Blip' streams together into one, which emits
-- /either/ of the original 'Blip' streams emit.  If both emit at the same
-- time, the right (second) one is favored.
--
-- Lazy on the first stream if the second stream is emitting.
--
-- If we discout laziness, this is @'merge' ('flip' 'const')@.
--
mergeR :: Blip a -> Blip a -> Blip a
mergeR _  b2@(Blip _) = b2
mergeR b1 _           = b1

-- | Destruct a 'Blip' by giving a default result if the 'Blip' is
-- non-occuring and a function to apply on the contents, if the 'Blip' is
-- occuring.
--
-- Try not to use if possible, unless you are a framework developer.  If
-- you're just making an application, try to use the other various
-- combinators in this library.  It'll help you preserve the semantics of
-- what it means to be 'Blip'py.
--
-- Analogous to 'maybe' from "Prelude".
blip :: b -> (a -> b) -> Blip a -> b
blip d _ NoBlip   = d
blip _ f (Blip x) = f x
