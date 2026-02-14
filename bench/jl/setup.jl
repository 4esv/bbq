#!/usr/bin/env julia
# One-time setup: install benchmark dependencies
using Pkg
Pkg.add(["CSV", "DataFrames", "RollingFunctions"])
println("Setup complete.")
