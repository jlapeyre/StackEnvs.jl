module StackEnv

export envs, pushenv!, rmenv!, sharedenvs, resetenvs!, using_from

import Base: LOAD_PATH

using Pkg: Pkg

"""
    resetenvs!()

Reset the list of stacked environments `LOAD_PATH` to its default state.
"""
function resetenvs!()
    empty!(LOAD_PATH)
    copyto!(Base.DEFAULT_LOAD_PATH, LOAD_PATH)
end

# This may not be very useful.
"""
   using_from(env::AbstractString, pkg::Symbol)

Do `using` on package `pkg` from environment `env`.

This is not really `using`, but rather calls `Base.require`
and then makes a `const` binding to the required module.
"""
function using_from(env::AbstractString, pkg::Symbol)
    pushenv!(env)
    try
        pkgmod = Base.require(Main, pkg)
        @eval Main const $pkg = $pkgmod
    finally
        rmenv!(env)
    end
    nothing
end

"""
    _user_depot()

Return path to the main user depot. On unix, this is normally `~/.julia`.
"""
function _user_depot()
    first(Base.DEPOT_PATH)
end

"""
    _isdefault(env::AbstractString)

Return `true` if `env` is a default environment, i.e.
one that was not added to `LOAD_PATH` by the user.
"""
function _isdefault(env::AbstractString)
    startswith(env, "/tmp/") && return true
    in(env, Base.DEFAULT_LOAD_PATH)
end

"""
    envs(all=false)

Return a `Vector` of all active environments. Default environments
are filtered out if `all==false`.
"""
function envs(all=false)
    if all
        return copy(LOAD_PATH)
    end
    [env for env in LOAD_PATH if ! _isdefault(env)]
end


"""
    _isdefault_shared_env(env::AbstractString)

Return `true` if `env` is a default, or startup, shared enviroment.

For example, this function returns `true` for `"v1.10"` and `false` for `"mysharedenv"`.
"""
function _isdefault_shared_env(env::AbstractString)
    startswith(env, r"v1\.|v0\.")
end

"""
    sharedenvs()

Return a list of defined shared environments, filtering out
the default shared enviroments. These need not be active or
in the list of stacked enviroments `LOAD_PATH`.
"""
function sharedenvs()
    envs = readdir(joinpath(_user_depot(), "environments"))
    ["@" * env for env in envs if !_isdefault_shared_env(env)]
end

"""
    pushenv!(env::AbstractString)

Add `env` to `LOAD_PATH`, the list of stacked environments and return `true`.
If `env` is already in `LOAD_PATH`, do nothing and return `false`.
"""
function pushenv!(env::AbstractString)
    in(env, LOAD_PATH) && return false
    push!(LOAD_PATH, env)
    true
end

"""
    rmenv!(env::AbstractString)

Remove `env` from `LOAD_PATH`, the list of stacked enviroments.
If `env` is not in `LOAD_PATH`, throw an error.
"""
function rmenv!(env::AbstractString)
    ienv = findfirst(==(env), LOAD_PATH)
    if ienv === nothing
        error("$env not in environment stack")
    end
    popat!(LOAD_PATH, ienv)
end

end # module StackEnv
