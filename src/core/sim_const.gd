class_name SimConst
extends RefCounted
## Global simulation constants. Every tuning number that is not species/building
## data lives here with its rationale so there are no unexplained magic numbers.

## Fixed simulation rate at 1x speed. Logic never reads frame delta.
const TICKS_PER_SECOND := 10
const TICKS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const TICKS_PER_YEAR := TICKS_PER_MONTH * MONTHS_PER_YEAR

## Spatial chunk edge in tiles; used by spatial index, render dirtiness and staggering.
const CHUNK := 16

## Units re-plan ("think") at most this often; staggered by slot so load is flat.
const THINK_INTERVAL := 8
## Vegetation/crop cellular update visits each chunk once per this many ticks.
const VEG_CYCLE_TICKS := 60
## City economic planning cadence.
const CITY_PLAN_INTERVAL := 30
## Max A* path requests served per tick. Excess requests wait a tick.
const PATH_BUDGET_PER_TICK := 48

const HUNGER_EAT_THRESHOLD := 50.0
const HUNGER_URGENT := 75.0
const HUNGER_MAX := 100.0
## Health lost per tick while fully starving (a healthy adult dies in ~250 ticks ≈ 0.7 years).
const STARVE_DAMAGE := 0.4
## Health lost per tick while standing on an unwalkable tile (drowning / buried).
const HAZARD_DAMAGE := 2.0
## Passive regeneration per tick when fed (hunger below eat threshold).
const REGEN_PER_TICK := 0.05

## Settlement founding rules.
const FOUND_MIN_SITE_SCORE := 48.0
const FOUND_MIN_CITY_DISTANCE := 22
const FOUND_SITE_RADIUS := 5
const CITY_START_RADIUS := 5
const CITY_JOIN_RADIUS := 12
## A cityless adult evaluates founding at most once per this many ticks.
const FOUND_EVAL_INTERVAL := 90

## Vegetation growth per VEG_CYCLE visit, scaled by fertility.
const VEG_GROWTH := 24.0
## Probability (per visit) that a treeless fertile tile next to forest turns to forest.
const FOREST_SPREAD_CHANCE := 0.012
## Per-visit chance an old forest tile thins back to grassland (natural turnover).
const FOREST_DIEBACK_CHANCE := 0.002
## Crop growth per VEG_CYCLE visit on farmland (0..255 maturity).
const CROP_GROWTH := 90.0
const CROP_MATURE := 240
## Soil nutrients on farmland (stored in WorldGrid.wood, unused on farmland).
## Each harvest drains SOIL_DRAIN; fields recover SOIL_RECOVER per vegetation visit
## (~6 visits/year). Crop growth and yield scale with nutrients, so intensively
## farmed land yields less and the land itself caps a city's food supply.
const SOIL_MAX := 255
const SOIL_DRAIN := 60
const SOIL_RECOVER := 7

const BUILDING_ID_NONE := -1
const CITY_NONE := -1
const UNIT_NONE := -1
