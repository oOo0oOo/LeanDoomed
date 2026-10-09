import Engine

def main (args : List String) : IO Unit := do
  if args == ["--smoke"] then Engine.run (some 3)
  else if args.isEmpty then Engine.run
  else throw <| IO.userError "Usage: LeanDoomed [--smoke]"
