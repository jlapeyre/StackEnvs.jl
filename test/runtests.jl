using StackEnvs
using Test
import Pkg

# Remove the environment from filesystem if it exists
function remove_from_filesystem(env_name)
    env_path = joinpath(Pkg.envdir(), env_name)
    isdir(env_path) || throw(ErrorException(lazy"Environment $env_name does not exist"))
    if isdir(env_path)
        rm(joinpath(env_path, "Project.toml"))
        rm(joinpath(env_path, "Manifest.toml"))
        rm(env_path)
    end
end

# JET seems to be making some false positives.
# Anyway, there are hundreds of complaints about Pkg that are beyond my control.
# include("test_jet.jl")

include("test_aqua.jl")

@testset "StackEnvs.jl" begin
    if !isdir(Pkg.envdir())
        mkdir(Pkg.envdir())
    end

    env_name = "stackenv" * string(rand(UInt), base=16)
    env = StackEnv(env_name, [:Example])
    @test StackEnvs._at_name(env) == "@" * env_name
    @test StackEnvs._no_at_name(env) == env_name

    @test !env_exists(env_name)
    @test !env_exists(env)
    @test !is_in_stack(env_name)
    @test !is_in_stack(env)

    try
        ensure_in_stack(env)
        @test env_exists(env_name)
        @test env_exists(env)
        @test is_in_stack(env_name)
        @test is_in_stack(env)

        proj_file_content = read_env(env)
        @test collect(keys(proj_file_content)) == ["Example"]

        push!(env.packages, :ZChop)
        ensure_in_stack(env)
        proj_file_content = read_env(env)
        @test sort!(collect(keys(proj_file_content))) == ["Example", "ZChop"]
    catch
        rethrow()
    finally
        remove_from_filesystem(env_name)
    end

    @test !env_exists(env_name)
    @test !env_exists(env)
    @test is_in_stack(env_name)
    @test is_in_stack(env)

    delete_from_stack!(env)
    @test !is_in_stack(env_name)
    @test !is_in_stack(env)

    # Does not error if it is already gone
    delete_from_stack!(env)
end
