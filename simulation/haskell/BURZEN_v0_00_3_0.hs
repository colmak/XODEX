module Main where

import Data.List (foldl', sortOn)
import Text.Printf (printf)

-- Core domain -----------------------------------------------------------------

data TowerType
  = ProteinTower
  | AutoRegressiveTokenTower
  | EnergyTower
  deriving (Eq, Show)

data TowerState = Active | Disabled | Cooling deriving (Eq, Show)

data Tower = Tower
  { towerId :: Int,
    towerType :: TowerType,
    position :: (Double, Double),
    attackPower :: Double,
    rangeRadius :: Double,
    state :: TowerState,
    cooldownRemaining :: Double,
    cooldownDuration :: Double,
    heat :: Double
  }
  deriving (Eq, Show)

data Enemy = Enemy
  { enemyId :: Int,
    location :: (Double, Double),
    velocity :: (Double, Double),
    health :: Double,
    threatLevel :: Double
  }
  deriving (Eq, Show)

data GameState = GameState
  { towers :: [Tower],
    enemies :: [Enemy],
    resources :: Double,
    tokenBank :: Double,
    tokenHistory :: [Double],
    tick :: Int,
    eventLog :: [String]
  }
  deriving (Eq, Show)

-- SPOC constraints --------------------------------------------------------------

data ConstraintSeverity = Soft | Hard deriving (Eq, Show)

data ConstraintResult = ConstraintResult
  { severity :: ConstraintSeverity,
    message :: String
  }
  deriving (Eq, Show)

type Constraint = GameState -> [ConstraintResult]

pass :: [ConstraintResult]
pass = []

mkViolation :: ConstraintSeverity -> String -> ConstraintResult
mkViolation sev msg = ConstraintResult sev msg

cooldownIntegrityConstraint :: Constraint
cooldownIntegrityConstraint gs =
  [ mkViolation Hard $ "Tower " ++ show (towerId t) ++ " has negative cooldown."
    | t <- towers gs,
      cooldownRemaining t < 0
  ]

heatSafetyConstraint :: Constraint
heatSafetyConstraint gs =
  [ mkViolation Hard $ "Tower " ++ show (towerId t) ++ " exceeded heat limit."
    | t <- towers gs,
      heat t > 100
  ]

resourceNonNegativeConstraint :: Constraint
resourceNonNegativeConstraint gs
  | resources gs < 0 = [mkViolation Hard "Resources dropped below zero."]
  | otherwise = pass

enemyBoundsConstraint :: Constraint
enemyBoundsConstraint gs =
  [ mkViolation Soft $ "Enemy " ++ show (enemyId e) ++ " moved outside recommended corridor."
    | e <- enemies gs,
      let (x, y) = location e,
      x < (-5) || x > 30 || y < (-10) || y > 10
  ]

checkConstraints :: [Constraint] -> GameState -> [ConstraintResult]
checkConstraints cs gs = concatMap ($ gs) cs

hasHardViolation :: [ConstraintResult] -> Bool
hasHardViolation = any ((== Hard) . severity)

-- NESOROX projection/collapse ---------------------------------------------------

data ProjectionReport = ProjectionReport
  { resultingState :: GameState,
    violations :: [ConstraintResult],
    collapsed :: Bool
  }
  deriving (Eq, Show)

projectState :: GameState -> (GameState -> GameState) -> [Constraint] -> ProjectionReport
projectState baseline candidateFn cs =
  let candidate = candidateFn baseline
      outcomes = checkConstraints cs candidate
   in if hasHardViolation outcomes
        then ProjectionReport
          { resultingState = collapseToSafe baseline outcomes,
            violations = outcomes,
            collapsed = True
          }
        else ProjectionReport
          { resultingState = candidate,
            violations = outcomes,
            collapsed = False
          }

collapseToSafe :: GameState -> [ConstraintResult] -> GameState
collapseToSafe gs rs =
  gs
    { towers = map coolTower (towers gs),
      eventLog = eventLog gs ++ ["NESOROX collapse engaged: " ++ summarize rs]
    }
  where
    coolTower t = t {state = Cooling, cooldownRemaining = max (cooldownDuration t) 1.0, heat = min (heat t) 80}
    summarize [] = "unknown violation"
    summarize xs = unwords (take 2 (map message xs))

-- WASMUTABLE sandbox ------------------------------------------------------------

data TowerCommand
  = FireAtNearest Int
  | GenerateTokens Int
  | RechargeEnergy Int
  deriving (Eq, Show)

data Plan = Plan
  { commands :: [TowerCommand],
    wasmTrace :: [String]
  }
  deriving (Eq, Show)

type Strategy = GameState -> Plan

data WasmutableSandbox = WasmutableSandbox
  { maxCommands :: Int,
    allowTokenGeneration :: Bool,
    allowAggressiveFire :: Bool
  }
  deriving (Eq, Show)

runWasmutable :: WasmutableSandbox -> Strategy -> GameState -> Either String Plan
runWasmutable cfg strategy gs =
  let rawPlan = strategy gs
      commandCount = length (commands rawPlan)
      hasTokenCmd = any isTokenCmd (commands rawPlan)
      hasFireCmd = any isFireCmd (commands rawPlan)
   in if commandCount > maxCommands cfg
        then Left "WASMUTABLE rejected plan: command budget exceeded"
        else
          if hasTokenCmd && not (allowTokenGeneration cfg)
            then Left "WASMUTABLE rejected plan: token mutation disabled"
            else
              if hasFireCmd && not (allowAggressiveFire cfg)
                then Left "WASMUTABLE rejected plan: aggressive fire disabled"
                else Right rawPlan
  where
    isTokenCmd (GenerateTokens _) = True
    isTokenCmd _ = False
    isFireCmd (FireAtNearest _) = True
    isFireCmd _ = False

-- Deterministic game mechanics --------------------------------------------------

processTurn :: [Constraint] -> WasmutableSandbox -> Strategy -> GameState -> ProjectionReport
processTurn cs sandbox strategy gs =
  let advanced = decayCooldowns (moveEnemies gs)
      planResult = runWasmutable sandbox strategy advanced
      candidateFn = case planResult of
        Left err -> \st -> st {eventLog = eventLog st ++ [err]}
        Right plan -> \st -> applyPlan plan st
      projected = projectState advanced candidateFn cs
   in projected {resultingState = (resultingState projected) {tick = tick gs + 1}}

moveEnemies :: GameState -> GameState
moveEnemies gs = gs {enemies = map stepEnemy (enemies gs)}
  where
    stepEnemy e =
      let (x, y) = location e
          (vx, vy) = velocity e
       in e {location = (x + vx, y + vy)}

decayCooldowns :: GameState -> GameState
decayCooldowns gs = gs {towers = map cool (towers gs)}
  where
    cool t = t {cooldownRemaining = max 0 (cooldownRemaining t - 1), heat = max 0 (heat t - 4)}

applyPlan :: Plan -> GameState -> GameState
applyPlan plan =
  foldl' (flip applyCommand) . appendLogs (wasmTrace plan)

appendLogs :: [String] -> GameState -> GameState
appendLogs logs gs = gs {eventLog = eventLog gs ++ logs}

applyCommand :: TowerCommand -> GameState -> GameState
applyCommand cmd gs = case cmd of
  FireAtNearest tid -> fireNearestFromTower tid gs
  GenerateTokens tid -> generateAutoRegressiveTokens tid gs
  RechargeEnergy tid -> rechargeTower tid gs

fireNearestFromTower :: Int -> GameState -> GameState
fireNearestFromTower tid gs =
  case lookupTower tid (towers gs) of
    Nothing -> gs {eventLog = eventLog gs ++ ["Tower " ++ show tid ++ " not found for fire command"]}
    Just t
      | state t /= Active -> gs {eventLog = eventLog gs ++ ["Tower " ++ show tid ++ " is not active"]}
      | cooldownRemaining t > 0 -> gs {eventLog = eventLog gs ++ ["Tower " ++ show tid ++ " is cooling"]}
      | otherwise ->
          case nearestEnemyInRange t (enemies gs) of
            Nothing -> gs {eventLog = eventLog gs ++ ["Tower " ++ show tid ++ " found no target in range"]}
            Just target ->
              let enemyAfterDamage = target {health = health target - attackPower t}
                  newEnemies = map (replaceEnemy enemyAfterDamage) (enemies gs)
                  pruned = filter ((> 0) . health) newEnemies
                  heatedTower = t {cooldownRemaining = cooldownDuration t, heat = heat t + 14}
               in gs
                    { enemies = pruned,
                      towers = map (replaceTower heatedTower) (towers gs),
                      eventLog =
                        eventLog gs
                          ++ [ "Tower " ++ show tid ++ " hit enemy " ++ show (enemyId target)
                             ]
                    }

generateAutoRegressiveTokens :: Int -> GameState -> GameState
generateAutoRegressiveTokens tid gs =
  case lookupTower tid (towers gs) of
    Nothing -> gs {eventLog = eventLog gs ++ ["Tower " ++ show tid ++ " missing for token generation"]}
    Just t
      | towerType t /= AutoRegressiveTokenTower -> gs {eventLog = eventLog gs ++ ["Tower " ++ show tid ++ " cannot generate tokens"]}
      | state t /= Active || cooldownRemaining t > 0 -> gs {eventLog = eventLog gs ++ ["Tower " ++ show tid ++ " unavailable for token pulse"]}
      | otherwise ->
          let prev = case tokenHistory gs of
                [] -> 0
                x : _ -> x
              generated = 3 + 0.45 * prev + attackPower t * 0.2
              t' = t {cooldownRemaining = cooldownDuration t, heat = heat t + 7}
           in gs
                { tokenBank = tokenBank gs + generated,
                  resources = resources gs + (generated * 0.5),
                  tokenHistory = generated : tokenHistory gs,
                  towers = map (replaceTower t') (towers gs),
                  eventLog = eventLog gs ++ [printf "Tower %d generated %.2f tokens" tid generated]
                }

rechargeTower :: Int -> GameState -> GameState
rechargeTower tid gs =
  case lookupTower tid (towers gs) of
    Nothing -> gs
    Just t ->
      let t' = t {state = Active, heat = max 0 (heat t - 15), cooldownRemaining = max 0 (cooldownRemaining t - 1)}
       in gs {towers = map (replaceTower t') (towers gs), eventLog = eventLog gs ++ ["Energy pulse on tower " ++ show tid]}

-- Helpers ----------------------------------------------------------------------

lookupTower :: Int -> [Tower] -> Maybe Tower
lookupTower tid = go
  where
    go [] = Nothing
    go (x : xs)
      | towerId x == tid = Just x
      | otherwise = go xs

replaceTower :: Tower -> Tower -> Tower
replaceTower replacement current
  | towerId replacement == towerId current = replacement
  | otherwise = current

replaceEnemy :: Enemy -> Enemy -> Enemy
replaceEnemy replacement current
  | enemyId replacement == enemyId current = replacement
  | otherwise = current

nearestEnemyInRange :: Tower -> [Enemy] -> Maybe Enemy
nearestEnemyInRange t es =
  case sortOn (distanceSq (position t) . location) inRange of
    [] -> Nothing
    x : _ -> Just x
  where
    inRange = filter (withinRange t) es

withinRange :: Tower -> Enemy -> Bool
withinRange t e = distance (position t) (location e) <= rangeRadius t

distance :: (Double, Double) -> (Double, Double) -> Double
distance a b = sqrt (distanceSq a b)

distanceSq :: (Double, Double) -> (Double, Double) -> Double
distanceSq (x1, y1) (x2, y2) = (x1 - x2) ^ (2 :: Int) + (y1 - y2) ^ (2 :: Int)

-- Sample BURZEN v0.00.3.0 strategy --------------------------------------------

burzenStrategyV0030 :: Strategy
burzenStrategyV0030 gs =
  let sortedTowers = sortOn towerId (towers gs)
      cmds = concatMap decide sortedTowers
   in Plan
        { commands = take 6 cmds,
          wasmTrace = ["WASMUTABLE strategy evaluated for tick " ++ show (tick gs)]
        }
  where
    decide t = case towerType t of
      ProteinTower -> [FireAtNearest (towerId t)]
      AutoRegressiveTokenTower -> [GenerateTokens (towerId t)]
      EnergyTower -> [RechargeEnergy (towerId t)]

initialState :: GameState
initialState =
  GameState
    { towers =
        [ Tower 1 ProteinTower (4, 0) 24 5 Active 0 2 0,
          Tower 2 AutoRegressiveTokenTower (6, 1) 10 0 Active 0 3 0,
          Tower 3 EnergyTower (2, -2) 0 0 Active 0 1 0
        ],
      enemies =
        [ Enemy 100 (0, 0) (1.2, 0.1) 48 1.0,
          Enemy 101 (-1, 1.5) (1.0, -0.05) 36 0.8,
          Enemy 102 (-2, -1.2) (0.9, 0.06) 60 1.3
        ],
      resources = 12,
      tokenBank = 0,
      tokenHistory = [],
      tick = 0,
      eventLog = ["Simulation initialized"]
    }

defaultConstraints :: [Constraint]
defaultConstraints =
  [ cooldownIntegrityConstraint,
    heatSafetyConstraint,
    resourceNonNegativeConstraint,
    enemyBoundsConstraint
  ]

defaultSandbox :: WasmutableSandbox
defaultSandbox =
  WasmutableSandbox
    { maxCommands = 8,
      allowTokenGeneration = True,
      allowAggressiveFire = True
    }

runSimulation :: Int -> GameState -> [ProjectionReport]
runSimulation n = take n . iterateStep
  where
    iterateStep gs =
      let report = processTurn defaultConstraints defaultSandbox burzenStrategyV0030 gs
       in report : iterateStep (resultingState report)

renderReport :: ProjectionReport -> String
renderReport report =
  let gs = resultingState report
      hardCount = length (filter ((== Hard) . severity) (violations report))
      softCount = length (filter ((== Soft) . severity) (violations report))
   in unlines
        [ "Tick " ++ show (tick gs),
          "  resources=" ++ printf "%.2f" (resources gs) ++ " tokenBank=" ++ printf "%.2f" (tokenBank gs),
          "  enemies=" ++ show (length (enemies gs)) ++ " collapsed=" ++ show (collapsed report),
          "  violations: hard=" ++ show hardCount ++ " soft=" ++ show softCount,
          "  latest-event=" ++ latestEvent gs
        ]

latestEvent :: GameState -> String
latestEvent gs = case reverse (eventLog gs) of
  [] -> "none"
  x : _ -> x

main :: IO ()
main = do
  putStrLn "BURZEN v0.00.3.0 Haskell prototype simulation"
  putStrLn "==========================================="
  mapM_ (putStrLn . renderReport) (runSimulation 8 initialState)
