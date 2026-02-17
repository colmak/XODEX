module Main where

import Text.Printf (printf)

data ResidueClass = NonPolar | PolarUncharged | PositivelyCharged | NegativelyCharged | Special deriving (Eq, Show)

data RegressionVector = RegressionVector
  { vecId :: Int,
    leftResidue :: ResidueClass,
    rightResidue :: ResidueClass,
    leftThermal :: Double,
    rightThermal :: Double,
    expectedStrength :: Double
  }
  deriving (Eq, Show)

affinity :: ResidueClass -> ResidueClass -> Double
affinity NonPolar NonPolar = 0.95
affinity NonPolar PolarUncharged = -0.35
affinity NonPolar PositivelyCharged = -0.20
affinity NonPolar NegativelyCharged = -0.20
affinity NonPolar Special = 0.22
affinity PolarUncharged PolarUncharged = 0.50
affinity PolarUncharged PositivelyCharged = 0.40
affinity PolarUncharged NegativelyCharged = 0.40
affinity PolarUncharged Special = 0.18
affinity PositivelyCharged PositivelyCharged = -0.72
affinity PositivelyCharged NegativelyCharged = 0.88
affinity PositivelyCharged Special = 0.24
affinity NegativelyCharged NegativelyCharged = -0.72
affinity NegativelyCharged Special = 0.24
affinity Special Special = 0.08
affinity a b = affinity b a

pairStrength :: ResidueClass -> ResidueClass -> Double -> Double -> Double
pairStrength left right tLeft tRight =
  let base = affinity left right
      thermal = (tLeft + tRight) / 2.0
      thermalMod = max 0.0 (1.0 - thermal * 0.40)
   in base * thermalMod

regressionVectors :: [RegressionVector]
regressionVectors =
  [ RegressionVector 0 NonPolar PositivelyCharged 0.50 0.51 (-0.1596),
    RegressionVector 1 NonPolar PolarUncharged 0.89 0.62 (-0.2443),
    RegressionVector 2 NegativelyCharged Special 0.55 0.73 0.17856,
    RegressionVector 3 NegativelyCharged Special 0.44 0.00 0.21888,
    RegressionVector 4 NonPolar NonPolar 0.29 0.10 0.87590,
    RegressionVector 5 NonPolar NegativelyCharged 0.68 0.21 (-0.1644),
    RegressionVector 6 PositivelyCharged PositivelyCharged 0.98 0.93 (-0.44496),
    RegressionVector 7 NegativelyCharged Special 0.64 0.72 0.17472,
    RegressionVector 8 NonPolar Special 0.54 0.29 0.18348,
    RegressionVector 9 PolarUncharged Special 0.31 0.85 0.13824,
    RegressionVector 10 PositivelyCharged PositivelyCharged 0.46 0.09 (-0.6408),
    RegressionVector 11 Special Special 0.50 0.12 0.07008,
    RegressionVector 12 Special Special 0.88 0.40 0.05952,
    RegressionVector 13 Special PositivelyCharged 0.84 0.56 0.17280,
    RegressionVector 14 NegativelyCharged Special 0.52 0.03 0.21360,
    RegressionVector 15 PolarUncharged PolarUncharged 0.82 0.96 0.32200,
    RegressionVector 16 Special NonPolar 0.72 0.43 0.16940,
    RegressionVector 17 PolarUncharged NegativelyCharged 0.88 0.85 0.26160,
    RegressionVector 18 NonPolar NegativelyCharged 0.67 0.71 (-0.1448),
    RegressionVector 19 Special PositivelyCharged 0.56 0.67 0.18096,
    RegressionVector 20 PositivelyCharged Special 0.80 0.50 0.17760,
    RegressionVector 21 NegativelyCharged NegativelyCharged 0.43 0.29 (-0.61632),
    RegressionVector 22 PositivelyCharged NonPolar 0.03 0.66 (-0.1724),
    RegressionVector 23 Special NegativelyCharged 0.80 0.93 0.15696,
    RegressionVector 24 PositivelyCharged PolarUncharged 0.26 0.49 0.34000,
    RegressionVector 25 Special NegativelyCharged 0.81 0.56 0.17424
  ]

approxEq :: Double -> Double -> Bool
approxEq a b = abs (a - b) <= 1.0e-9

main :: IO ()
main = do
  let checks =
        [ (vecId v, pairStrength (leftResidue v) (rightResidue v) (leftThermal v) (rightThermal v), expectedStrength v)
          | v <- regressionVectors
        ]
      failures = [(i, got, expct) | (i, got, expct) <- checks, not (approxEq got expct)]
  putStrLn "BURZEN TowerGraph Formal Model v0.00.5.0"
  printf "Regression vectors: %d\n" (length regressionVectors)
  if null failures
    then putStrLn "All deterministic regression vectors passed."
    else mapM_ (\(i, got, expct) -> printf "Vector %d mismatch got=%.8f expected=%.8f\n" i got expct) failures
