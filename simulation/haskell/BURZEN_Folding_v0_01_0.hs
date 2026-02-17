module Main where

import Data.List (nub)
import Text.Printf (printf)

data ResidueClass = Polar | NonPolar | ChargedPos | ChargedNeg | Special deriving (Eq, Show)
data BondType = HBond | Hydrophobic | Electrostatic | VdW | Steric deriving (Eq, Show)
data Conformation = Unfolded | Partial | Native | Misfolded deriving (Eq, Show)

data Node = Node
  { nodeId :: Int,
    residue :: ResidueClass,
    pos :: (Int, Int)
  }
  deriving (Eq, Show)

data Bond = Bond
  { fromId :: Int,
    toId :: Int,
    bondType :: BondType,
    energyContrib :: Double
  }
  deriving (Eq, Show)

data Environment = Environment
  { thermalState :: Double,
    ph :: Double,
    phosphorylationStabilize :: Bool
  }
  deriving (Eq, Show)

affinity :: ResidueClass -> ResidueClass -> Double
affinity Polar Polar = -0.8
affinity Polar ChargedPos = -1.1
affinity Polar ChargedNeg = -1.1
affinity Polar NonPolar = 0.4
affinity Polar Special = -0.2
affinity NonPolar NonPolar = -1.3
affinity NonPolar ChargedPos = 0.8
affinity NonPolar ChargedNeg = 0.8
affinity NonPolar Special = 0.2
affinity ChargedPos ChargedNeg = -1.8
affinity ChargedPos ChargedPos = 1.2
affinity ChargedPos Special = -0.3
affinity ChargedNeg ChargedNeg = 1.2
affinity ChargedNeg Special = -0.3
affinity Special Special = 0.1
affinity a b = affinity b a

pairEnergy :: Environment -> Node -> Node -> Double
pairEnergy env l r =
  let base = affinity (residue l) (residue r)
      thermalPenalty = thermalState env * 0.14
      phPenalty = abs (ph env - 7.0) * 0.05
      pBonus = if phosphorylationStabilize env then (-0.25) else 0.0
   in base + thermalPenalty + phPenalty + pBonus

isNeighbor :: Node -> Node -> Bool
isNeighbor a b =
  let (ax, ay) = pos a
      (bx, by) = pos b
      dx = abs (ax - bx)
      dy = abs (ay - by)
   in dx + dy == 1 || (dx == 1 && dy == 1)

inferBondType :: Double -> Node -> Node -> BondType
inferBondType e l r
  | e > 1.0 = Steric
  | residuePair == [ChargedNeg, ChargedPos] = Electrostatic
  | residue l == NonPolar && residue r == NonPolar = Hydrophobic
  | residue l == Special || residue r == Special = VdW
  | otherwise = HBond
  where
    residuePair = nub [residue l, residue r]

buildBonds :: Environment -> [Node] -> [Bond]
buildBonds env nodes =
  [ Bond (nodeId l) (nodeId r) (inferBondType e l r) e
    | (i, l) <- zip [0 ..] nodes,
      r <- drop (i + 1) nodes,
      isNeighbor l r,
      let e = pairEnergy env l r,
      e <= (-0.2)
  ]

globalEnergy :: Environment -> [Node] -> Double
globalEnergy env nodes =
  let pairs =
        [ pairEnergy env l r
          | (i, l) <- zip [0 ..] nodes,
            r <- drop (i + 1) nodes,
            isNeighbor l r
        ]
      thermalPenalty = thermalState env * 0.2 * fromIntegral (length nodes)
   in sum pairs + thermalPenalty

conformation :: Environment -> Double -> Conformation
conformation env stability
  | thermalState env > 0.8 && stability < 0.65 = Misfolded
  | stability >= 0.75 = Native
  | stability >= 0.45 = Partial
  | otherwise = Unfolded

main :: IO ()
main = do
  let env = Environment 0.2 7.0 False
      nodes = [Node 1 ChargedPos (0, 0), Node 2 ChargedNeg (1, 0), Node 3 Polar (2, 0)]
      bonds = buildBonds env nodes
      energy = globalEnergy env nodes
  putStrLn "BURZEN Folding Formal Model v0.01.0"
  printf "Bonds=%d Energy=%.6f\n" (length bonds) energy
  mapM_ print bonds
