# StackEnvs

[![Build Status](https://github.com/jlapeyre/StackEnvs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jlapeyre/StackEnvs.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jlapeyre/StackEnvs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jlapeyre/StackEnvs.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

`StackEnvs` provides tools for minimal management of a shared environment that is meant to be used from your "stacked environment" but never to be active itself.

This is useful if you are developing a package and want to use some other packages without polluting any environment.

It is meant to be used in a script that you `include` when, for example, developing a particular package, and want some other particular
packages to be available.

```julia
using StackEnvs
env = StackEnv("my_env", ["PackA", "PackB"])
ensure_in_stack(env)
```

or more simply,

```julia
using StackEnvs
ensure_in_stack("my_env", ["PackA", "PackB"])
```

After including the script, you can immediately `using PackA`.

> [!WARNING]
> `StackedEnvs` pays no attention to version numbers, uuids. It can't remove any packages. It is useful
  for some simple, straightforward, use cases.

> [!WARNING]
> The test suite adds and deletes an environment to your `~/.julia/environments` directory. Something could potentially go wrong causing it
  to delete your entire home directory. I've taken some steps to minimize this risk. There is nothing like `rm -r *` in the test. Rather, the
  two `toml` files are deleted, then the empty directory is deleted. If any of this should fail, the test suite will fail.

> [!WARNING]
> `StackedEnvs` uses some non-API functions in `Base`. But the way these are used is simple and should be fixable.

### Example

```julia-repl
julia> using StackEnvs

julia> env = StackEnv("my_env", ["StatsBase"])
StackEnv("my_env", [:StatsBase])

julia> env_exists(env)
false

julia> is_in_stack(env)
false

julia> ensure_in_stack(env)
  Activating new project at `~/.julia/environments/my_env`
   Resolving package versions...

julia> is_in_stack(env)
true

julia> env_exists(env)
true

julia> using StatsBase

julia> push!(env, "ILog2")
2-element Vector{Symbol}:
 :StatsBase
 :ILog2

julia> ensure_in_stack(env)
  Activating project at `~/.julia/environments/my_env`
   Resolving package versions...
    Updating `~/.julia/environments/my_env/Project.toml`
  [2cd5bd5f] + ILog2 v2.0.0
    Updating `~/.julia/environments/my_env/Manifest.toml`
  [2cd5bd5f] + ILog2 v2.0.0
  Activating project at `~/github/jlapeyre/StackEnvs`
StackEnv("my_env", [:StatsBase, :ILog2])

julia> ensure_in_stack(env)  # Nothing to do. Returns in 30 micro seconds
StackEnv("my_env", [:StatsBase, :ILog2])
```

<!--  LocalWords:  StackEnvs julia env StackEnv PackA StackedEnvs uuids toml repl ILog2
<!--  LocalWords:  StatsBase 2cd5bd5f
 -->
