include("plot_utils.jl")
include("../simulator/adm_task_generator.jl")
using POMDPs
using Plots
using GridInterpolations
using LocalFunctionApproximation
include("../solver/local_approx_policy_eval.jl")
using Serialization
using LinearAlgebra
using Distributions

ended_in_collision(r) = (r[end] == 1.0)

function sum_prob(mdp, a)
    if a[1][1] isa LaneFollowingAccelBlinker
        return sum([mean([action_probability(mdp, aii) for aii in ai]) for ai in a])
    else
        return sum([action_probability(mdp, ai) for ai in a])
    end
end




# Generates a joint action from the individual policies. Supply an action function for individual action selection
function joint_policy(combined_pomdp, policies, o::Vector{Float64}, ind_policy, sample)
    egoid = combined_pomdp.egoid
    as = [index_to_action(combined_pomdp,ind_policy(policies[i], decompose_scene(convert_s(BlinkerScene, o, combined_pomdp), [i, egoid]), sample)) for i=1:length(policies)]
    push!(as, LaneFollowingAccelBlinker(0,0,false,false))
end

function make_video(pomdp, policy, name)
    o,a,r,scenes = policy_rollout(pomdp, policy, pomdp.initial_scene, save_scenes = true)
    make_video(scenes, pomdp.models,pomdp.roadway,name; egoid=pomdp.egoid)
end

function compare_policies(pomdp, policies, pol_names; N = 100)
    Np = length(policies)
    p1 = plot(title="Action Likelihood", ylabel = "Average logprob of Actions", xticks = ([1:Np...], pol_names))
    p2 = plot(title="Collision Success", ylabel = "Fraction of Episodes Ending in Collision", xticks = ([1:Np...], pol_names))
    for pi in 1:Np
        policy = policies[pi]
        pol_name = pol_names[pi]
        tot_fails = 0
        tot_log_prob = 0
        tot_steps = 0

        for n=1:N
            o,a,r,scenes = policy_rollout(pomdp, policy, pomdp.initial_scene, save_scenes = true)
            tot_fails += ended_in_collision(r)
            tot_log_prob += sum_prob(pomdp, a)
            tot_steps += length(r)
        end

        frac_fails = tot_fails / N
        avg_logprob = tot_log_prob / tot_steps

        bar!(p1, [pi], [avg_logprob], label="")
        bar!(p2, [pi], [frac_fails], label="")

    end
    return plot(p1,p2)
end

decomposed, combined = generate_decomposed_scene(dt = 0.18)
policies = [deserialize(string("policy_decomp_", i, ".jls")) for i in 1:length(decomposed)]

# Rollout the individual policies
pomdp1 = decomposed[1]
pol_names = ["Max", "Random", "Importance"]
pols = [
    (o) -> action(policies[1], convert_s(BlinkerScene, o, pomdp1), false),
    (o) -> random_action(policies[1], convert_s(BlinkerScene, o, pomdp1), false),
    (o) -> action(policies[1], convert_s(BlinkerScene, o, pomdp1), true)
    ]

combined_pols = [
    (o) -> joint_policy(combined, policies, o, action, false), # max
    (o) -> joint_policy(combined, policies, o, random_action, false), # random
    (o) -> joint_policy(combined, policies, o, action, true), # importance
    ]


savefig(compare_policies(pomdp1, pols, pol_names), "decomp1_comparision_of_policies.pdf")
savefig(compare_policies(combined, combined_pols, pol_names), "combined_comparison_of_policies.pdf")

for i=1:length(decomposed)
    my_pol = (o) -> action(policies[i], convert_s(BlinkerScene, o, decomposed[i]))
    name = string("decomposed_", i, ".gif")
    make_video(decomposed[i], my_pol, name)
end


make_video(combined, combined_pols[1], "combined_max.gif")

