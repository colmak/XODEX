module Main where

import Data.List (nubBy)
import Text.Printf (printf)

data ResidueClass = NonPolar | PolarUncharged | PositivelyCharged | NegativelyCharged | Special deriving (Eq, Show)

data TowerNode = TowerNode
  { nodeId :: Int,
    residueClass :: ResidueClass,
    pos :: (Int, Int),
    thermalState :: Double
  }
  deriving (Eq, Show)

data Bond = Bond
  { fromId :: Int,
    toId :: Int,
    affinityType :: String,
    strength :: Double
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

pairStrength :: TowerNode -> TowerNode -> Double
pairStrength a b =
  let base = affinity (residueClass a) (residueClass b)
      thermal = (thermalState a + thermalState b) / 2.0
      thermalMod = max 0.0 (1.0 - thermal * 0.40)
   in base * thermalMod

neighbors4 :: [TowerNode] -> [(TowerNode, TowerNode)]
neighbors4 nodes =
  [ (a, b)
    | (i, a) <- zip [0 ..] nodes,
      b <- drop (i + 1) nodes,
      let (ax, ay) = pos a,
      let (bx, by) = pos b,
      abs (ax - bx) + abs (ay - by) == 1
  ]

buildBonds :: Double -> [TowerNode] -> [Bond]
buildBonds threshold nodes =
  [ Bond (nodeId a) (nodeId b) typ s
    | (a, b) <- neighbors4 nodes,
      let s = pairStrength a b,
      abs s >= threshold,
      let typ = if s > 0 then "attractive" else "repulsive"
  ]

avgStability :: [Bond] -> Double
avgStability [] = 0.0
avgStability bs = sum (map strength bs) / fromIntegral (length bs)

misfoldRisk :: [Bond] -> Double
misfoldRisk [] = 0.0
misfoldRisk bs =
  let negative = length [b | b <- bs, strength b < 0]
   in fromIntegral negative / fromIntegral (length bs)

main :: IO ()
main = do
  let nodes =
        [ TowerNode 1 NonPolar (0, 0) 0.1,
          TowerNode 2 PolarUncharged (1, 0) 0.2,
          TowerNode 3 NegativelyCharged (2, 0) 0.2,
          TowerNode 4 PositivelyCharged (2, 1) 0.2
        ]
      bonds = buildBonds 0.2 nodes
  putStrLn "BURZEN TowerGraph Formal Model v0.00.5.0"
  printf "Bonds=%d AvgStability=%.6f MisfoldRisk=%.6f\n" (length bonds) (avgStability bonds) (misfoldRisk bonds)
  mapM_ print bonds
