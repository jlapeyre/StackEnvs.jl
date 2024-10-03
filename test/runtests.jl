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


@testset "StackEnvs.jl" begin
    if !isdir(Pkg.envdir())
        mkdir(Pkg.envdir())
    end

    env_name = "stackenv" * string(rand(UInt), base=16)
    packages = [:Example]
    env = StackEnv(env_name, packages)
    @test StackEnvs._at_name(env) == "@" * env_name
    @test StackEnvs._no_at_name(env) == env_name

    @test !env_exists(env_name)
    @test !env_exists(env)
    @test !is_in_stack(env_name)
    @test !is_in_stack(env)

    # There are two equivalent methods for ensure_in_stack
    for func in (() -> ensure_in_stack(env), () -> ensure_in_stack(env_name, packages))
        try
            env = func()
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

            # Should do approximately nothing. Also not error
            ensure_in_stack(env)
            @test env_exists(env)
            @test is_in_stack(env)
            proj_file_content = read_env(env)
            @test sort!(collect(keys(proj_file_content))) == ["Example", "ZChop"]

            # We don't have a precise test. This has added packages again.
            update_env(env)
            @test env_exists(env)
            @test is_in_stack(env)
            update_env(env.name, env.packages)
            @test env_exists(env)
            @test is_in_stack(env)

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

    current_project = Base.active_project()
    try
        ensure_in_stack(env)
        activate_env(env)
        @test Base.active_project() == joinpath(Pkg.envdir(), env_name, "Project.toml")
    catch
        rethrow()
    finally
        Pkg.activate(current_project)
        remove_from_filesystem(env_name)
    end

    env2 = StackEnv("newenv")
    @test env2.name == "newenv"
    @test isempty(env2.packages)

    for str in ("dog", "@dog")
        @test StackEnvs._at_name(str) == "@dog"
        @test StackEnvs._at_name(Symbol(str)) == "@dog"
        @test StackEnvs._no_at_name(str) == "dog"
        @test StackEnvs._no_at_name(Symbol(str)) == "dog"
    end
end

# JET seems to be making some false positives.
# Anyway, there are hundreds of complaints about Pkg that are beyond my control.
# include("test_jet.jl")

include("test_aqua.jl")
