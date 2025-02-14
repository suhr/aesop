/-
Copyright (c) 2022 Jannis Limperg. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jannis Limperg
-/

import Aesop.RuleTac.Basic

open Lean
open Lean.Meta

namespace Aesop.RuleTac

def applyConst (decl : Name) : RuleTac := SimpleRuleTac.toRuleTac λ input => do
  apply input.goal (← mkConstWithFreshMVarLevels decl)
  -- TODO optimise mvar analysis

def applyFVar (userName : Name) : RuleTac := SimpleRuleTac.toRuleTac λ input =>
  withMVarContext input.goal do
    let decl ← getLocalDeclFromUserName userName
    apply input.goal (mkFVar decl.fvarId)
    -- TODO optimise mvar analysis

-- Tries to apply each constant in `decls`. For each one that applies, a rule
-- application is returned. If none applies, the tactic fails.
def applyConsts (decls : Array Name) : RuleTac := λ input => do
  let initialState ← saveState
  let apps ← decls.filterMapM λ decl => do
    try
      let goals ← apply input.goal (← mkConstWithFreshMVarLevels decl)
      let postState ← saveState
      let (goals, introducedMVars) ← getProperGoalsAndNewMVars input.mvars goals
      let assignedMVars ← getAssignedMVars input.mvars
      return some { postState, goals, introducedMVars, assignedMVars }
    catch _ =>
      return none
    finally
      restoreState initialState
  if apps.isEmpty then throwError
    "failed to apply any of these declarations:{MessageData.node $ decls.map toMessageData}"
  return { applications := apps, postBranchState? := none }

end RuleTac
