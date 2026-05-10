# AI Systems Guide

LuaAgentSim implements four complementary AI decision-making systems.
Agents use them in layers — the Utility AI selects goals, Behavior Trees
execute behaviors, GOAP plans multi-step sequences, and FSMs manage
low-level state transitions.

## 1. Finite State Machine (FSM)

The simplest AI layer. Each agent has a current state with transitions
driven by conditions.

**States:** idle, foraging, combat, fleeing, resting, socializing, trading, gathering

**File:** `agents/fsm/fsm.lua`

```lua
local FSM = require("agents.fsm.fsm")
local machine = FSM.createAgentFSM()

-- In update loop:
machine:update(dt, context)
```

## 2. Utility AI

Scores a set of possible actions using response curves and selects
the highest-scoring action. Personality traits influence scores.

**Actions:** eat, drink, rest, flee, fight, gather, trade, socialize, explore, craft

**File:** `agents/utility_ai/utility_ai.lua`

Each action has a scoring function that returns a value between 0 and ~1.5.
Higher score = higher priority.

**Personality influence:**
- Openness → exploration score
- Extraversion → socialization score
- Agreeableness → trade/cooperation scores
- Neuroticism → flee sensitivity
- Conscientiousness → gather/craft scores

## 3. Behavior Trees (BT)

Hierarchical decision trees with composites (Sequence, Selector, Parallel)
and decorators (Inverter, Repeater, Cooldown).

**Node types:**
- `Action` — leaf node that performs an action
- `Condition` — leaf node that checks a predicate
- `Sequence` — runs children in order, fails on first failure
- `Selector` — runs children in order, succeeds on first success
- `Parallel` — runs all children simultaneously
- `Inverter` — inverts child result
- `Repeater` — repeats child N times
- `Cooldown` — prevents re-execution for a duration

**Files:** `agents/behavior_trees/bt_nodes.lua`, `bt_runner.lua`, `agent_behaviors.lua`

## 4. Goal-Oriented Action Planning (GOAP)

Backward-chaining A* planner that finds optimal action sequences
to reach a goal state from the current state.

**File:** `agents/goap/goap.lua`

```lua
local GOAP = require("agents.goap.goap")

local current = { nearFood = true, hasFood = false, isHungry = true }
local goal    = { isHungry = false }
local plan    = GOAP.plan(current, goal, GOAP.AGENT_ACTIONS)
-- plan = { "get_food", "eat" }
```

## 5. Perception System

Agents have limited perception — they can only "see" entities
within their perception radius.

**File:** `agents/perception/perception.lua`

Features:
- Radius-based visibility using spatial grid
- Distance-sorted visible entity list
- Enemy detection (different faction)
- Nearest-entity queries by component

## 6. Memory System

Ring-buffer event log with knowledge base.

**File:** `agents/memory/memory.lua`

Features:
- Records events (saw_agent, was_attacked, traded, etc.)
- Knowledge base: last-known position of other entities
- Auto-updates from perception output
- Forgetting old knowledge

## 7. Influence Maps

Tactical AI tool for evaluating spatial control.

**File:** `agents/perception/influence_map.lua`

Layers:
- Friendly influence
- Hostile influence
- Resource density
- Danger zones
- Combined tactical score

## 8. Advanced Features

### Evolutionary Algorithms (`agents/advanced/evolutionary.lua`)
- Fitness calculation from survival, wealth, skills, social network
- Tournament selection
- Personality trait crossover and mutation
- Generational tracking
- Flocking/swarm intelligence primitives

### Reinforcement Learning Hooks (`agents/advanced/rl_hooks.lua`)
- OpenAI Gym-style interface: observe(), step(), reset()
- 14-action discrete action space
- Normalized observation vector
- Reward shaping for survival, needs, and exploration
