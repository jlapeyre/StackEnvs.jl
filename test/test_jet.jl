# Borrowed from QuantumOpticsBase
using Test
using StackEnvs
using JET

using JET: ReportPass, BasicPass, InferenceErrorReport, UncaughtExceptionReport

# Custom report pass that ignores `UncaughtExceptionReport`
# Too coarse currently, but it serves to ignore the various
# "may throw" messages for runtime errors we raise on purpose
# (mostly on malformed user input)
struct MayThrowIsOk <: ReportPass end

# ignores `UncaughtExceptionReport` analyzed by `JETAnalyzer`
(::MayThrowIsOk)(::Type{UncaughtExceptionReport}, @nospecialize(_...)) = return

# forward to `BasicPass` for everything else
function (::MayThrowIsOk)(report_type::Type{<:InferenceErrorReport}, @nospecialize(args...))
    BasicPass()(report_type, args...)
end

@testset "jet" begin
#    if get(ENV,"STACK_ENVS_JET_TEST","")=="true"
    if true
        rep = report_package(
            "StackEnvs";
            report_pass=MayThrowIsOk(), # TODO have something more fine grained than a generic "do not care about thrown errors"
        )
        @show rep
        @test length(JET.get_reports(rep)) == 0
    end
end # testset
