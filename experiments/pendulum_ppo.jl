include("../simulator/gym_continous.jl")
include("../solver/ppo.jl")
using Flux: ADAM
using Flux.Tracker: gradient, update!, hook
using LinearAlgebra, Plots

env = make("Pendulum-v0", :human_pane)
env._env.action_space
env.max_episode_steps


input_size, output_size = o_dim(env), a_dim(env)
policy = init_policy([input_size, 100, 50, 25, output_size])
params = to_params(policy)


opt = ADAM(0.001, (0.9, 0.999))
loss() = ppo_batch_loss(env, policy, 125, 1., 0.95, 1.)

N, max_norm = 100, 1.
for i=1:N
    grads = gradient(() -> loss(), params)
    update_with_clip!(opt, grads, params, max_norm)

    println("Finished epoch, ", i, " return: ", episode_returns(env, policy, 10), " grad norms: ", clipped_grad_norms(grads, params, max_norm))
end

i, done, o, tot_r = 1, false, reset!(env), 0
theta, dtheta = [], []
while !done
    a = sample_action(policy, o)
    global o, r, done, d = step!(env, a)
    global tot_r += r
    push!(theta, env._env.state[1])
    push!(dtheta, env._env.state[2])
    global i += 1
    (i > env.max_episode_steps) && break
end
println("total reward: ", tot_r)

scatter(theta, dtheta, xlabel="theta", ylabel="dtheta")

