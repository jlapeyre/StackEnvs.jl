"""
    module StackEnvs

Failites for managing an environment that is not active, but in the stack.

The module defines [`StackEnv`](@ref) which represents an environment meant to used
in the enironment stack rather than as an active environment.

There are some functions missing. For example, for adding and removing packages from the
`StackEnv`. This can be done manually, but is would be a bit fiddle. These functions might
be added later.
"""
module StackEnvs

using Pkg: Pkg
using TOML: TOML

export StackEnv,
    ensure_in_stack,
    is_in_stack,
    env_exists,
    create_env,
    delete_from_stack!,
    activate_env,
    update_env,
    read_env

const StrOrSym = Union{AbstractString, Symbol}

"""
    struct StackEnv

Data for defining a shared environment to be used in the environment stack.

When working with a particular package, you might frequently use certain other packages that
are not in the dependencies of the particular one. `StackEnv` is meant to help manage these
other packages. You can do this by hand as well. But it's sometimes not easy to remember
what you want to do and exactly how to do it.

`StackEnv` helps you create a shared environment and make sure it is in your stack of environments
so that its packages are visibile when it is not the active environment. You are *not* meant
to do work with the environment in `StackEnv` activated.

The most important function for creating an `StackEnv` and making it visible is [`ensure_in_stack`](@ref).

# Fields
- `name::String`: the name of the extra environment
- `packages::Vector{Symbol}`: A list of packages to use to initialize the environment.

See [`update_env`](@ref) [`create_env`](@ref), [`ensure_in_stack`](@ref), [`env_exists`](@ref),
[`activate_env`](@ref), [`is_in_stack`](@ref), [`delete_from_stack!`](@ref).

# Examples
```jldoctest
julia> StackEnv("an_extra_env", [:Example])
StackEnv("an_extra_env", [:Example])

julia> StackEnv("@an_extra_env", [:Example])
StackEnv("an_extra_env", [:Example])
```
"""
struct StackEnv
    name::String
    packages::Vector{Symbol}

    function StackEnv(name::AbstractString, packages::AbstractVector)
        return new(_no_at_name(name), [Symbol(p) for p in packages])
    end
end

"""
    StackEnv(env_name::AbstractString)

Initialize an `StackEnv` with an empty list of packages.

# Examples
```jldoctest
julia> StackEnv("an_extra_env")
StackEnv("an_extra_env", Symbol[])

julia> StackEnv("@an_extra_env")
StackEnv("an_extra_env", Symbol[])
```
"""
StackEnv(env_name::AbstractString) = StackEnv(env_name, Symbol[])

# Make sure `name` starts with "@".
# Prepend an "@" only if it is missing.
function _at_name(name::StrOrSym)::String
    sname = string(name)
    startswith(sname, "@") && return sname
    return string("@", name)
end

# Make sure `name` does *not* start with "@"
# Remove "@" if present.
function _no_at_name(name::StrOrSym)::String
    sname = string(name)
    isempty(sname) && return ""
    startswith(sname, "@") && return string(@view sname[2:end])
    return string(sname)
end

_at_name(env::StackEnv)::String = _at_name(env.name)
_no_at_name(env::StackEnv)::String = _no_at_name(env.name)

function Base.push!(env::StackEnv, package::StrOrSym)
    push!(env.packages, Symbol(package))
end

"""
    ensure_in_stack(env_name::AbstractString, env_packages::AbstractVector)::StackEnv

Create `env = StackEnv(env_name, env_packages)`, run `ensure_in_stack(env)` and return `env`.

Elements of `env_packages` should be `AbstractString`s or `Symbol`s.

See [`StackEnv`](@ref).

# Examples
```julia-repl
julia> ensure_in_stack("my_extra_env", [:PackageA, :PackageB]);
```
"""
function ensure_in_stack(env_name::AbstractString, env_packages::AbstractVector{<:StrOrSym})
    env = StackEnv(env_name, [Symbol(p) for p in env_packages])
    ensure_in_stack(env)
    return env
end

"""
    ensure_in_stack(env::StackEnv)::StackEnv

Ensure that a shared environment `env.name` with `env.packages` is in your stack.

Recall that the environment stack is `Base.LOAD_PATH`.

If `env.name` does not name a shared environment, create it and add `env.packages`.
Furthermore, if `env.name` is not in the stack, add it to the stack.

After this runs, the packages `env.packages` should be available in whatever project
is active.

`ensure_in_stack` compares `env.packages` to the list of packages in the `Project.toml` for the environment
and adds any missing packages that you may have added since the environment was first created.

Things that are not supported:
* removing packages from the environment for any reason.
* Specifying or checking versions, uuids, etc.

The function [`update_env`](@ref) will unconditionally add all packages in `env.packages`
to the environment, which may perform an upgrade (I'm not sure).

See [`StackEnv`](@ref).
"""
function ensure_in_stack(env::StackEnv)::StackEnv
    env_exists(env) || create_env(env)
    atenv = _at_name(env) # This must already be the case!
    add_missing(env)
    maybepushenv!(atenv)
    return env
end

function add_missing(env::StackEnv)
    env_exists(env) || return nothing
    existing_packages = collect(keys(read_env(env)))
    missing_packs = String[]
    for pack in env.packages
        spack = string(pack)
        spack in existing_packages || push!(missing_packs, spack)
    end
    isempty(missing_packs) && return
    _add_packages(env.name, missing_packs)
end

"""
    maybepushenv!(env::AbstractString)

Add `env` to `LOAD_PATH`, the list of stacked environments and return `true`.
If `env` is already in `LOAD_PATH`, do nothing and return `false`.
"""
function maybepushenv!(env::AbstractString)
    in(env, LOAD_PATH) && return false
    push!(LOAD_PATH, env)
    return true
end

"""
    is_in_stack(env_name::AbstractString)::Bool

Return `true` if the shared environment `env_name` is in the environment stack.

If `env_name` does not start with `'@'`, it is prepended. The stack is `Base.LOAD_PATH`.
"""
function is_in_stack(env_name::AbstractString)::Bool
    return _at_name(env_name) in Base.LOAD_PATH
end

"""
    is_in_stack(env::StackEnv)::Bool

Return `true` if the shared environment `env.name` is in the environment stack.

See [`StackEnv`](@ref).
"""
is_in_stack(env::StackEnv)::Bool = is_in_stack(env.name)

"""
    env_exists(env::StackEnv)::Bool

Return `true` if the shared environment in `env` already exists.

See [`StackEnv`](@ref).
"""
env_exists(env::StackEnv)::Bool = env_exists(env.name)

"""
    env_exists(env_name::AbstractString)::Bool

Return `true` if the shared environment `env_name` already exists.

`env_name` may begin with "@" or not.

This environment might be activated via `Pkg.activate(env_name)`
If done from the `pkg` repl, the name must start with `'@'`.
"""
function env_exists(env_name::AbstractString)::Bool
    return _no_at_name(env_name) in readdir(Pkg.envdir())
end

"""
    create_env(env::StackEnv)

Create a shared environment named `env.name` with packages `env.packages`.

If the shared environment `env.name` already exists, an error is thrown.

See [`StackEnv`](@ref).
"""
function create_env(env::StackEnv)
    env_exists(env) &&
        throw(ErrorException(lazy"Environment \"$(env.name)\" already exists"))
    return update_env(env)
end

"""
    update_env(env::StackEnv)

Add all packages in `env.packages` to the shared environment `env.name`.

If the shared environment `env.name` does not exist, it is created.

This is the same as [`create_env`](@ref) except no check is made that the environment
does not already exist. Any packages that have already been added to the environment
will be added again, which should be little more than a no-op.

# Examples

Say I want to add `CondaPkg.jl` to the packages in `env::StackEnv`.

```julia-repl
julia> env.packages
2-element Vector{Symbol}:
 :PythonCall
 :StatsBase

julia> push!(env, :CondaPkg)
3-element Vector{Symbol}:
 :PythonCall
 :StatsBase
 :CondaPkg

julia> update_env(env)
  Activating project at `~/.julia/environments/qkruntime_extra`
  ...
  Updating `~/.julia/environments/qkruntime_extra/Project.toml`
 [992eb4ea] + CondaPkg v0.2.24
```
"""
function update_env(env::StackEnv)
    _add_packages(env.name, env.packages)
end

# Add `packages` to shared environment `name`.
function _add_packages(name::AbstractString, packages::AbstractVector{<:StrOrSym})
    current_project = Base.active_project()
    try
        activate_env(name)
        for pkg in packages
            Pkg.add(string(pkg))
        end
    catch
        rethrow()
    finally
        Pkg.activate(current_project)
    end
end

"""
    update_env(env_name::AbstractString, env_packages::AbstractVector)::StackEnv

Create `env = StackEnv(env_name, env_packages)` and create or update the environment `env_name`.

The shared environment `env_name` will be created if it does not exist.
Possible existing packages in the the environment are not removed. If
packages in `env_packages` are already in the environment, they are added again.

Elements of `env_packages` should be `AbstractString`s or `Symbol`s.

`update_env` is the same as `create_env(env_name, env_packages)` except that the
latter will throw an error if the environment already exists.

See [`StackEnv`](@ref).
"""
function update_env(env_name::AbstractString, env_packages::AbstractVector)
    env = StackEnv(env_name, [Symbol(p) for p in env_packages])
    update_env(env)
    return env
end

"""
    delete_from_stack!(env::StackEnv)

Delete environment `env.name` if and wherever it occurs in the stack `Base.LOAD_PATH`.

See [`StackEnv`](@ref).
"""
function delete_from_stack!(env::StackEnv)
    return delete_from_stack!(env.name)
end

"""
    delete_from_stack!(env_name::Union{AbstractString, Symbol})

Delete environment `env_name` if and wherever it occurs in the stack `Base.LOAD_PATH`.

See [`StackEnv`](@ref).
"""
function delete_from_stack!(env_name::StrOrSym)
    stack = Base.LOAD_PATH
    atname = _at_name(env_name)
    inds = findall(==(atname), stack)
    if !isnothing(inds) && !isempty(inds)
        return deleteat!(stack, inds...)
    end
end

"""
    activate_env(env::StackEnv)

Activate the shared environment `env.name`.

You might want to do this to add or remove packages from the environment.
But it is not necessary to activate it to use it.

See [`StackEnv`](@ref), [`create_env`](@ref), [`ensure_in_stack`](@ref),
[`env_exists`](@ref).
"""
function activate_env(env::StackEnv)
    return activate_env(env.name)
end

function activate_env(env_name::StrOrSym)
    return Pkg.activate(_no_at_name(env_name); shared=true)
end

"""
    read_env(env_name::StrOrSym)

Read the `Project.toml` in environment `env_name`.

A `Dict` mapping package names to uuids is returned.
"""
function read_env(env_name::StrOrSym)
    env_name = string(env_name)
    proj_file = joinpath(Pkg.envdir(), env_name, "Project.toml")
    return TOML.parsefile(proj_file)["deps"]
end

read_env(env::StackEnv) = read_env(env.name)

end # module StackEnvs
