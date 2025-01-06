using StackEnvs
using Aqua: Aqua

@testset "aqua test ambiguities" begin
    Aqua.test_ambiguities([StackEnvs, Core, Base])
end

@testset "aqua unbound_args" begin
    Aqua.test_unbound_args(StackEnvs)
end

@testset "aqua undefined exports" begin
    Aqua.test_undefined_exports(StackEnvs)
end

@testset "aqua piracies" begin
    Aqua.test_piracies(StackEnvs)
end

@testset "aqua project extras" begin
    Aqua.test_project_extras(StackEnvs)
end

@testset "aqua stale deps" begin
    Aqua.test_stale_deps(StackEnvs)
end

@testset "aqua deps compat" begin
    Aqua.test_deps_compat(StackEnvs)
end
