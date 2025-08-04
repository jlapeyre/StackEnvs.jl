@setup_workload begin
    # Putting some things in `setup` can reduce the size of the
    # precompile file and potentially make loading faster.
    nothing
    using StackEnvs
    @compile_workload begin
        # All calls in this block will be precompiled, regardless of whether
        # they belong to your package or not (on Julia 1.8 and higher)
        # These don't take very long to compile anyway.
        # Especially for larger values of N, the run time is much larger than compile time.
        import Pkg
        if isdir(Pkg.envdir()) # In CI, dir does not exist
            e1 = StackEnv("anenv", []; shared=true)
            e2 = StackEnv("anenv", []; shared=false)
            e3 = StackEnv("anenv", [:a, :b, :c]; shared=false)
            e4 = StackEnv("anenv", ["abc", "de"]; shared=false)
            env_exists(e1)
            env_in_stack(e1)
            env_exists(e2)
            env_in_stack(e2)
            list_envs()
            list_envs(r"^some")
            # The following does not help. At all.
            # I think it is the REPL itself that is laggy.
            for env in (e1, e2, e3, e4)
                io  = IOBuffer()
                show(io, MIME"text/plain"(), e1);
                show(stdout, MIME"text/plain"(), e1);
                show(stdout, e1);
                String(take!(io))
                io  = IOBuffer()
                show(io, e1);
                String(take!(io))
                s1 = string(e1)
                s2 = string(e2)
                print(s1)
                print(s2)
                print(e1)
                print(e2)
            end
        end
    end
end
