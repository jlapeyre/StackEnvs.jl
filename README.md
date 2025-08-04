# StackEnvs

[![Build Status](https://github.com/jlapeyre/StackEnvs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jlapeyre/StackEnvs.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jlapeyre/StackEnvs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jlapeyre/StackEnvs.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

`StackEnvs` provides tools for minimal management of Julia `Pkg` environments that are meant to be used from your "stacked environment" but never to be active itself. The environments may be shared or not.

This is useful if you are developing a package and want to use some other packages without polluting any environment.

It may be used in a script that you `include` when, for example, developing a particular package, and want some other particular
packages to be available.

```julia
julia> using StackEnvs
julia> env = ensure_in_stack("my_env", ["Example", "OtherPackage"]; shared=true)
  Activating new project at `~/.julia/environments/my_env`
  ...
StackEnv("my_env", [:Example, :OtherPackage], true)
```

After including the script, you can immediately `using OtherPackage`.

Detailed documentation may be found in the docstring for `StackEnv`.

### Example

```julia-repl
julia> using StackEnvs

julia> env = StackEnv("my_env", ["StatsBase"]; shared=true)
StackEnv("my_env", [:StatsBase], true)

julia> env_exists(env)
false

julia> env_in_stack(env)
false

julia> ensure_in_stack(env)
  Activating new project at `~/.julia/environments/my_env`
   Resolving package versions...

julia> env_in_stack(env)
true

julia> env_exists(env)
true

julia> using StatsBase

julia> add_packages!(env, "ILog2")
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
StackEnv("my_env", [:StatsBase, :ILog2], true)

julia> ensure_in_stack(env)  # Nothing to do. Returns in 30 micro seconds
StackEnv("my_env", [:StatsBase, :ILog2], true)
```


> [!WARNING]
> `StackedEnvs` pays no attention to version numbers, uuids. It can't remove any packages. It is useful for some simple, straightforward, use cases.

> [!WARNING]
> The test suite adds and deletes an environment to your `~/.julia/environments` directory. Something could potentially go wrong causing it to delete your entire home directory. I've taken some steps to minimize this risk. There is nothing like `rm -r *` in the test. Rather, the two `toml` files are deleted, then the empty directory is deleted. If any one of these steps should fail, the test suite fails immediately.

> [!WARNING]
> `StackedEnvs` uses some non-API functions in `Base`. But the way these are used is simple and should be fixable easily if internal changes occur.

## Docstring

    StackEnv(name::AbstractString, packages=nothing; shared::Bool=false, read::Bool=false)

Create and return a `StackEnv` object with name `name`, and list (iterable) of package names `packages`.
Package names may be symbols or strings.

Creating a `StackEnv` object will *not* create a Julia Pkg environment on disk. See `ensure_in_stack`[@ref] for this.

If `shared` is `true`, the functions for creating and manipulating the environment will assume that it is shared.
Otherwise `name` will be assumed to be a directory path corresponding to the environment (that is, containing `Project.toml`).
Tildes in `name` will be expanded to the user's home directory when needed. If `name` is a single word, it will be
assumed to be a subdirectory of the current directory.

If `packages` is `nothing`, then the list of packages will be read from the existing environment specified by `name`.
If the environment does not exist, an `ErrorException` is thrown.

If `packages` is an empty iterable, then the package list will be initialized to `Symbol[]`.

# Examples

```jldoctest
julia> StackEnv("an_extra_env", [:Example]) # not-shared by default
StackEnv("an_extra_env", [:Example], false)

julia> StackEnv("an_extra_env", [:Example]; shared=true)
StackEnv("an_extra_env", [:Example], true)

julia> StackEnv("existing_env", shared=true)
StackEnv("existing_env", [:Example, :OtherPackage], true)
```

Use `?? StackEnv` for extended help.

# Extended help

    struct StackEnv

Data for defining a shared/not-shared environment to be used in the environment stack.

```julia
StackEnv("envname", [:Example, :OtherPackage])
StackEnv("envname2", [:OtherPackageA, :OtherPackageB]; shared=false)
```

Julia searches for a package in a list of "environments", loading the package from the
first environment where it is found. An environment is a folder with a file `Project.toml`
listing packages. This list is called the stack and is stored in the global `Vector` called `LOAD_PATH`.

When developing a package, you might use certain other packages that are not in its
dependencies. `StackEnv` is meant to help manage these other packages. You can do this by
hand as well.  But you'll have to remember exactly what you want exactly how to do it.

`StackEnv` helps you create a shared or not-shared environment and make sure it is in your stack of environments
so that its packages are visible when it is not the active environment. You are *not* meant
to do work with the environment in `StackEnv` activated.

The most important function for creating a `StackEnv` and making it visible is [`ensure_in_stack`](@ref).

`StackEnv` also includes convenience functions such as `list_envs`.

# Fields
- `name::String`: the name of the extra environment
- `packages::Vector{Symbol}`: A list of packages to use to initialize the environment.
- `shared::Bool`: True if the environment is shared.

# Functions

See doc strings for further information.
* [`ensure_in_stack`](@ref) - Add an env to the stack if not there, creating it and adding packages if needed.
* [`create_env`](@ref) - Create an environment with a given name and list of packages.
* [`update_env`](@ref) - Add all packages in `env.packages` to the environment `env.name`.
* [`env_exists`](@ref) - Return `true` if the environment in `env` already exists (may or may not be in the stack).
* [`env_in_stack`](@ref) - Return `true` if a given environment is in the environment stack.
* [`list_envs`](@ref) - List all shared environments in the Julia depot, or only those matching a string/regex.
* [`activate_env`](@ref) - Activate environment `env.name` (not normally needed).
* [`delete_from_stack!`](@ref) - Delete a given environment if, and wherever it occurs, in the stack.
* [`read_env`](@ref) - Return list of package names in the `Project.toml` in given environment
* [`get_env_dir_path`](@ref) - Return absolute path to the directory of the environment

# Shared and not-shared environments

Julia distinguishes between shared and not-shared environments as follows.
`Pkg.activate("myenv")` activates an environment in a subfolder `./myenv/` of the current folder.
`Pkg.activate("@myenv")` activates a *shared* environment, typically in `~/.julia/environments/myenv/`.
Note that the `@` character is never in the folder name. It just tells `Pkg` which directory to look in.

`StackEnv` only supports both shared and not-shared environments. The `struct StackEnv` includes
a boolean field `shared` whose value determines whether the environment is shared. The default value
for this field is `false`.

However, we treat names with and without the initial `'@'` the same.
The character `'@'` will be prepended to or removed as needed depending on the context and whether the enviroment is shared.
Rather, we determine whether an enviroment is shared by reading the field `shared` in the struct `StackEnv`,
In addtion many functions in `StackEnvs` take a keyword argument `shared`.

<!-- LocalWords:  StackEnvs julia env StackEnv PackA StackedEnvs uuids toml repl ILog2 -->
<!-- LocalWords:  StatsBase 2cd5bd5f -->
