# Better to *not* add a module-level docstring,
# because `? StackEnvs` will then display the README.md instead
module StackEnvs

using Pkg: Pkg
using TOML: TOML

export StackEnv,
    ensure_in_stack,
    create_env,
    update_env,
    env_exists,
    env_in_stack,
    list_envs,
    activate_env,
    delete_from_stack!,
    read_env,
    add_packages!,
    get_env_dir_path

const StrOrSym = Union{AbstractString, Symbol}

"""
    StackEnv(name::AbstractString, packages::AbstractVector=nothing; shared::Bool=false, read::Bool=false)

Create and return a `StackEnv` object with name `name`, and list of packages `packages`.

Creating a `StackEnv` object will *not* create a Julia Pkg environment on disk. See `ensure_in_stack`[@ref] for this.

If `shared` is `true`, the functions for creating and manipulating the environment will assume that it is shared.
Otherwise `name` will be assumed to be a directory path corresponding to the environment (that is, containing `Project.toml`).
A tilde at the beginning of `name` will be expanded to the user's home directory when needed. If `name` is a single word, it will be
assumed to be a subdirectory of the current directory.

If `packages` is `nothing` and `read` is `true`, then the list of packages will be read from the existing environment specified
by `name`. If the environment does not exist, an `ErrorException` is thrown. If `package` is a `Vector`, empty or not, and `read`
is `true`, an `ErrorException` is thrown.

If `packages` is `nothing` and `read` is `false`, then an empty list `Symbol[]` will be created.

# Examples

```jldoctest
julia> StackEnv("an_extra_env", [:Example]) # not-shared by default
StackEnv("an_extra_env", [:Example], true)

julia> StackEnv("an_extra_env", [:Example]; shared=false) # not shared
StackEnv("an_extra_env", [:Example], false)

julia> StackEnv("existing_env", shared=true, read=true)
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
"""
struct StackEnv
    name::String
    packages::Vector{Symbol}
    shared::Bool

    function StackEnv(name::AbstractString, packages=nothing; shared::Bool=false)
        env_dir_name = _no_at_name(name)
        if shared && (isabspath(expanduser(env_dir_name)) || length(splitpath(env_dir_name)) != 1)
            throw(ArgumentError(lazy"A shared environment name must be a single word. Got \"$env_dir_name\""))
        end
        if isnothing(packages)
            env_exists(env_dir_name; shared=shared) || throw(ErrorException(lazy"Unable to find environment \"$env_dir_name\" for reading."))
            packages = sort!(collect(keys(read_env(env_dir_name; shared=shared))))
        end
        return new(env_dir_name, [Symbol(p) for p in packages], shared)
    end
end

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

# Careful. Even if shared=true, the dir name has no @at.
# You can't rely on these two for everything.
_at_name(env::StackEnv)::String = _at_name(env.name)
_no_at_name(env::StackEnv)::String = _no_at_name(env.name)

function _get_at_name(name::StrOrSym, shared::Bool)::String
    shared ? _at_name(name) : _no_at_name(name)
end

function add_packages!(env::StackEnv, packages::StrOrSym...)
    push!(env.packages, map(Symbol, packages))
end

"""
    ensure_in_stack(env_name::AbstractString, env_packages::AbstractVector=nothing; shared::Bool=false)::StackEnv

Create `env = StackEnv(env_name, env_packages; shared=shared)`, run `ensure_in_stack(env)` and return `env`.

Elements of `env_packages` should be `AbstractString`s or `Symbol`s.

# Examples
```julia-repl
julia> ensure_in_stack("my_extra_env", [:PackageA, :PackageB]; shared=false); # or shared = true
```
"""
function ensure_in_stack(env_name::AbstractString, env_packages=nothing; shared::Bool=false)
    if isnothing(env_packages)
        env = StackEnv(env_name; shared=shared)
    else
        env = StackEnv(env_name, [Symbol(p) for p in env_packages]; shared=shared)
    end
    ensure_in_stack(env)
    return env
end

"""
    ensure_in_stack(env::StackEnv)::StackEnv

Ensure that an environment `env.name` with `env.packages` is in your stack.

Recall that the environment stack is `Base.LOAD_PATH`.

If `env.name` does not name an environment, create it and add `env.packages`.
Furthermore, if `env.name` is not in the stack, add it to the stack.
The location of the environment and prepending/removing `'@'` depends on `env.shared`.

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
    add_missing(env)
    maybepushenv!(env)
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
    _add_packages(env.name, missing_packs; shared=env.shared)
end

function maybepushenv!(env::StackEnv)
    maybepushenv!(env.name; shared=env.shared)
end

"""
    maybepushenv!(env_name::AbstractString; shared::Bool=false)

Add `env` to `LOAD_PATH`, the list of stacked environments and return `true`.
If `env` is already in `LOAD_PATH`, do nothing and return `false`.

The character `'@'` will be prepended to or removed as needed depending the keyword argument `shared`.
"""
function maybepushenv!(env_name::AbstractString; shared::Bool=false)
    name = _get_at_name(env_name, shared)
    in(name, LOAD_PATH) && return false
    push!(LOAD_PATH, name)
    return true
end

"""
    env_in_stack(env_name::AbstractString; shared::Bool=false)::Bool

Return `true` if the environment `env_name` is in the environment stack.

The character `'@'` will be prepended to or removed as needed depending the keyword argument `shared`.
The stack is `Base.LOAD_PATH`.
"""
function env_in_stack(env_name::AbstractString; shared::Bool=false)::Bool
    name = _get_at_name(env_name, shared)
    return name in Base.LOAD_PATH
end

"""
    env_in_stack(env::StackEnv)::Bool

Return `true` if the environment `env.name` is in the environment stack.

See [`StackEnv`](@ref).
"""
env_in_stack(env::StackEnv)::Bool = env_in_stack(env.name; shared=env.shared)

"""
    env_exists(env::StackEnv)::Bool

Return `true` if the environment in `env` already exists.

The character `'@'` will be prepended to or removed from `env_name` according to `env.shared`.

See [`StackEnv`](@ref).
"""
env_exists(env::StackEnv)::Bool = env_exists(env.name; shared=env.shared)

# This is not needed
"""
    get_env_dir_path(env::StackEnv)
"""
function get_env_dir_path(env::StackEnv)
    get_env_dir_path(env.name, env.shared)
end

"""
    get_env_dir_path(env_name::AbstractString, shared::Bool)

Return the absolute path to the directory of the environment `env_name`.

If `shared` is `true`, a subdirectory of the directory of shared environments is returned.

If `shared` is false, the absolute path determined by `env_name`, with tilde expaned to
the user's home directory (on linux and macos) is returned.
"""
function get_env_dir_path(env_name::AbstractString, shared::Bool)
    if shared
        return joinpath(Pkg.envdir(), env_name)
    end
    return abspath(expanduser(env_name))
end

"""
    env_exists(env_name::AbstractString; shared::Bool=false)::Bool

Return `true` if the environment `env_name` already exists.

The character `'@'` will be prepended to or removed from `env_name` according to `shared`.

This environment might be activated via `Pkg.activate(env_name)`
If done from the `pkg` repl, the name must start with `'@'`.
"""
function env_exists(env_name::AbstractString; shared::Bool=false)::Bool
    env_dir_name = _no_at_name(env_name) # Never have @ on the dir name
    shared && return env_dir_name in list_envs(;all=true)
    isdir(get_env_dir_path(env_dir_name, shared))
end

# Accept only strings in `list` that match `regex`.
# If `invert` is `true`, accept only those that do not match.
function _filter_strings(regex, list; invert=false)
    f = invert ? (!) : identity
    return filter(s -> f(occursin(regex, s)), list)
end

"""
    list_envs(search=nothing; all=false)::Vector

Return a list of all existing shared environment names in the depot.

If `search` is a string or regex, then return only matching names.

If `all` is `true`, then include default environments, for example,
"v1.0", v"1.12", etc. When you start `julia`, one of these environments
is created and activated by default.

For exact matching, see [`env_exists`](@ref).
"""
function list_envs(search=nothing; all=false)
    filenames = readdir(Pkg.envdir())
    isnothing(search) || (filenames = _filter_strings(search, filenames))
    all && return filenames
    return _filter_strings(r"^v\d+\.\d+", filenames; invert=true)
end

"""
    create_env(env::StackEnv)

Create a environment named `env.name` with packages `env.packages`.

This will create a folder in the appropriate location and write `Project.tom`
and `Manifest.toml` files.

If the environment `env.name` already exists, an error is thrown.

The character `'@'` will be prepended to or removed from `env_name` according to `env.shared`.

See [`StackEnv`](@ref).
"""
function create_env(env::StackEnv)
    env_exists(env) &&
        throw(ErrorException(lazy"Environment \"$(env.name)\" already exists"))
    return update_env(env)
end

"""
    update_env(env::StackEnv)

Add all packages in `env.packages` to the environment `env.name`.

If the environment `env.name` does not exist, it is created.

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

julia> add_packages!(env, :CondaPkg)
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
    _add_packages(env.name, env.packages; shared=env.shared)
end

# Add `packages` to shared environment `name`.
function _add_packages(name::AbstractString, packages::AbstractVector{<:StrOrSym}; shared::Bool=false)
    current_project = Base.active_project()
    try
        if !shared
            name = get_env_dir_path(name, shared)
        end
        activate_env(name; shared=shared)
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
    update_env(env_name::AbstractString, env_packages::AbstractVector; shared::Bool=false)::StackEnv

Create `env = StackEnv(env_name, env_packages; shared=shared)` and create or update the environment `env_name`.

The environment `env_name` will be created if it does not exist. This may included creating
a directory and populating it with `.toml` files. Possible existing packages
in the the environment are not removed. If packages in `env_packages` are already in the
environment, they are added again.

The environment will be shared or not according the keyword argument `shared`.

Elements of `env_packages` should be `AbstractString`s or `Symbol`s.

`update_env` is the same as `create_env` except that the latter will throw an error if the environment already exists.

The character `'@'` will be prepended to or removed from `env_name` according to the keyword argument `shared`.

See [`StackEnv`](@ref).
"""
function update_env(env_name::AbstractString, env_packages::AbstractVector; shared::Bool=false)
    env_dir_name = _no_at_name(env_name)
    env = StackEnv(env_dir_name, [Symbol(p) for p in env_packages]; shared=shared)
    update_env(env)
    return env
end

"""
    delete_from_stack!(env::StackEnv)

Delete environment `env.name` if and wherever it occurs in the stack `Base.LOAD_PATH`.

See [`StackEnv`](@ref).
"""
function delete_from_stack!(env::StackEnv)
    name = _get_at_name(env.name, env.shared)
    return delete_from_stack!(name; shared=env.shared)
end

"""
    delete_from_stack!(env_name::Union{AbstractString, Symbol}; shared::Bool=false)

Delete environment `env_name` if and wherever it occurs in the stack `Base.LOAD_PATH`.

The character `'@'` will be prepended to or removed from `env_name` according to the keyword argument `shared`.

See [`StackEnv`](@ref).
"""
function delete_from_stack!(env_name::StrOrSym; shared::Bool=false)
    name = _get_at_name(env_name, shared)
    stack = Base.LOAD_PATH
    inds = findall(==(name), stack)
    if !isnothing(inds) && !isempty(inds)
        return deleteat!(stack, inds...)
    end
end

"""
    activate_env(env::StackEnv)
    activate_env(env_name::StrOrSym; shared::Bool=false)

Activate the environment `env.name`, or `env_name`.

You might want to do this to add or remove packages from the environment.
But it is not necessary to activate it to use it.

The character `'@'` will be prepended to or removed from `env_name` according to the keyword argument `shared`.

See [`StackEnv`](@ref), [`create_env`](@ref), [`ensure_in_stack`](@ref),
[`env_exists`](@ref).
"""
function activate_env(env::StackEnv)
    return activate_env(env.name; shared=env.shared)
end

function activate_env(env_name::StrOrSym; shared::Bool=false)
    return Pkg.activate(_no_at_name(env_name); shared=shared)
end

"""
    read_env(env_name::StrOrSym; all=false, shared::Bool=false)::Dict

Return list of package names in the `Project.toml` in environment `env_name`.

A `Dict` mapping package names to uuids is returned.

By default, only the section `"deps"` is returned.
If `all` is true the entire `Project.toml` is returned.
"""
function read_env(env_name::StrOrSym; all=false, shared::Bool=false)
    env_dir_name = _no_at_name(string(env_name))
    proj_file = joinpath(get_env_dir_path(env_dir_name, shared), "Project.toml")
    parsed = TOML.parsefile(proj_file)
    return all ? parsed : parsed["deps"]
end

"""
    read_env(env::StackEnv)

Call `read_env(env.name; all=false)`.
"""
read_env(env::StackEnv) = read_env(env.name; shared=env.shared)

end # module StackEnvs

#  LocalWords:  not-shared myenv subfolder julia toml LOAD_PATH StackEnv ensure_in_stack v1
#  LocalWords:  list_envs search_envs env create_env update_env env_exists env_in_stack Bool
#  LocalWords:  activate_env delete_from_stack read_env jldoctest an_extra_env env_name 12
#  LocalWords:  env_packages AbstractString julia-repl my_extra_env PackageA PackageB uuids
#  LocalWords:  prepended repl no-op CondaPkg
