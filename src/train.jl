"""
`sciml_train`

### Unconstrained Optimization

```julia
function sciml_train(loss, _θ, opt = DEFAULT_OPT, adtype = DEFAULT_AD,
                     _data = DEFAULT_DATA, args...;
                     callback = (args...) -> false, maxiters = get_maxiters(data),
                     kwargs...)
```

### Box Constrained Optimization

```julia
function sciml_train(loss, θ, opt = DEFAULT_OPT, adtype = DEFAULT_AD,
                     data = DEFAULT_DATA, args...;
                     lower_bounds, upper_bounds,
                     callback = (args...) -> (false), maxiters = get_maxiters(data),
                     kwargs...)
```

## Optimizer Choices and Arguments

For a full definition of the allowed optimizers and arguments, please see the
[Optimization.jl](https://galacticoptim.sciml.ai/dev/) documentation. As
sciml_train is an interface over Optimization.jl, all of its optimizers and
arguments can be used from here.

## Loss Functions and Callbacks

Loss functions in `sciml_train` treat the first returned value as the return.
For example, if one returns `(1.0, [2.0])`, then the value the optimizer will
see is `1.0`. The other values are passed to the callback function. The callback
function is `callback(p, args...)` where the arguments are the extra returns from the
loss. This allows for reusing instead of recalculating. The callback function
must return a boolean where if `true`, then the optimizer will prematurely end
the optimization. It is called after every successful step, something that is
defined in an optimizer-dependent manner.

## Default AD Choice

The current default AD choice is dependent on the number of parameters.
For <50 parameters both ForwardDiff.jl and Zygote.jl gradients are evaluated
and the fastest is used. If both methods fail, finite difference method
is used as a fallback. For ≥50 parameters Zygote.jl is used.
More refinements to the techniques are planned.

## Default Optimizer Choice

By default, if the loss function is deterministic than an optimizer chain of
ADAM -> BFGS is used, otherwise ADAM is used (and a choice of maxiters is required).
"""
function sciml_train(loss, θ, opt=OptimizationPolyalgorithms.PolyOpt(), adtype=nothing, args...;
                     lower_bounds=nothing, upper_bounds=nothing, cb = nothing,
                     callback = (args...) -> (false),
                     maxiters=nothing, kwargs...)

    @warn "sciml_train is being deprecated in favor of direct usage of Optimization.jl. Please consult the Optimization.jl documentation for more details. Optimization's PolyOpt solver is the polyalgorithm of sciml_train"

    if adtype === nothing
        if length(θ) < 50
            fdtime = try
                ForwardDiff.gradient(x -> first(loss(x)), θ)
                @elapsed ForwardDiff.gradient(x -> first(loss(x)), θ)
            catch
                Inf
            end
            zytime = try
                Zygote.gradient(x -> first(loss(x)), θ)
                @elapsed Zygote.gradient(x -> first(loss(x)), θ)
            catch
                Inf
            end

            if fdtime == zytime == Inf
                @warn "AD methods failed, using numerical differentiation. To debug, try ForwardDiff.gradient(loss, θ) or Zygote.gradient(loss, θ)"
                adtype = Optimization.AutoFiniteDiff()
            elseif fdtime < zytime
                adtype = Optimization.AutoForwardDiff()
            else
                adtype = Optimization.AutoZygote()
            end

        else
            adtype = Optimization.AutoZygote()
        end
    end
    if !isnothing(cb)
      callback = cb
    end

    optf = Optimization.OptimizationFunction((x, p) -> loss(x), adtype)
    optfunc = Optimization.instantiate_function(optf, θ, adtype, nothing)
    optprob = Optimization.OptimizationProblem(optfunc, θ; lb=lower_bounds, ub=upper_bounds, kwargs...)
    if maxiters !== nothing
        Optimization.solve(optprob, opt, args...; maxiters, callback = callback, kwargs...)
    else
        Optimization.solve(optprob, opt, args...; callback = callback, kwargs...)
    end
end
