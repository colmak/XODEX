{-# LANGUAGE ForeignFunctionInterface #-}

module NESOROX_Eigenstate_v0_1
  ( EpigeneticMap(..)
  , CellState(..)
  , Eigenstate(..)
  , computeEigenstate
  , toCodexPayload
  , c_eigenstate_compute
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Base64.URL as B64
import qualified Data.ByteString.Char8 as BS
import Data.Digest.Pure.SHA (sha256, showDigest)
import Data.List (foldl')
import Foreign.C.String (CString, newCString)

newtype EpigeneticMap = EpigeneticMap [Double] deriving (Eq, Show)

data CellState = CellState
  { genomeAxis :: !Double
  , epigeneticMap :: !EpigeneticMap
  , cascadeSignal :: !Double
  , stressIndex :: !Double
  } deriving (Eq, Show)

data Eigenstate = Eigenstate
  { energySetpoint :: !Double
  , epigeneticProfile :: !Double
  , cascadeReadiness :: !Double
  , stressResilience :: !Double
  , differentiationAxis :: !Double
  } deriving (Eq, Show)

computeEigenstate :: CellState -> Eigenstate
computeEigenstate st =
  let EpigeneticMap marks = epigeneticMap st
      epi = if null marks then 0 else foldl' (+) 0 marks / fromIntegral (length marks)
      stressR = max 0 (1 - stressIndex st)
      diffAxis = genomeAxis st * 0.6 + epi * 0.4
  in Eigenstate
      { energySetpoint = 0.5 + cascadeSignal st * 0.3 - stressIndex st * 0.2
      , epigeneticProfile = epi
      , cascadeReadiness = cascadeSignal st
      , stressResilience = stressR
      , differentiationAxis = diffAxis
      }

checksum8 :: ByteString -> ByteString
checksum8 payload = BS.pack (take 8 (showDigest (sha256 payload)))

toCodexPayload :: Eigenstate -> ByteString
toCodexPayload e =
  let raw = BS.pack $
        show (energySetpoint e) <> "," <>
        show (epigeneticProfile e) <> "," <>
        show (cascadeReadiness e) <> "," <>
        show (stressResilience e) <> "," <>
        show (differentiationAxis e)
      payload = B64.encode raw
  in BS.concat ["XDX1.", payload, ".", checksum8 payload]

foreign export ccall c_eigenstate_compute :: CString -> IO CString

c_eigenstate_compute :: CString -> IO CString
c_eigenstate_compute _ = do
  let st = CellState 0.5 (EpigeneticMap [0.55, 0.52, 0.58]) 0.7 0.2
  newCString (BS.unpack (toCodexPayload (computeEigenstate st)))
