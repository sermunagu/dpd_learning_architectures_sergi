# Conditional hidden-layer continuation protocol

Declared before diagnosis and training, 2026-11-04. One real continuation of
the saved mixed P310 + LS network is authorized. No previous fit is repeated.
Only mask-permitted fc1 weights and its 12 biases may update. All fcOut
weights/biases, all pruned zeros, masks, normalization and architecture stay
fixed. No dlaccelerate, pruning, readout refit, hardware or CFR is used.

Use the exact normalized Z/target, phase rotation and identification rows in
the completed readout-LS prepared.mat. Verify provenance against the mixed
protocol and October source, and reproduce the saved LS prediction exactly.
Do not regenerate features or normalization statistics.

## Gradient diagnosis before training

Use the original weightedLoss and the same forward/dlgradient code that the
continuation uses. Accumulate sample-weighted minibatch means over all original
identification rows in fixed natural order, with the historical batch size.
Accumulate diagnostic gradients in double, preserving the native single
learnables and double CB inputs/targets. Use this identical convention for
both endpoint diagnoses. Report raw active/pruned norms and magnitudes,
per-neuron hidden statistics and permitted-output gradients separately.
Require initial native identification loss to agree with the saved normalized
LS loss within 1e-7 absolute (different native batch reduction paths).

For finite differences, use a temporary double copy of the stored parameters
to avoid differencing rounded single losses. Compare native AD gradients with
double-copy AD gradients, then check six predetermined components: the first
active input weight and bias of hidden neurons 1, 6 and 12. Central-difference
step is eps(double)^(1/3)*max(1,abs(parameter)). No step is selected from data.
This validates the smooth derivative represented by the stored weights;
it is not a bitwise derivative of a quantized computation.

Predeclared gates: double finite-difference discrepancy <=1e-8+1e-4*abs(g);
native/double gradient L2 discrepancy <=1e-6+1e-3*norm(g_double), per learnable
array; normalized prediction relative L2 <=1e-6. The initial permitted-output
gradient L2 must be <=1e-5, consistent with the LS endpoint's precision floor.
No small-gradient requirement applies to its excluded connection or to the
final output gradient after the hidden features have changed. Verify unchanged
weights, masks, normalization, network state and RNG after diagnosis.

No gradient magnitude is used to choose a learning rate, epoch count, seed,
mask or architecture. A mathematical/dimensional/provenance failure stops the
real experiment and must be reported before any training.

## Training controls recovered from the original protocol

Read the October mixed protocol, its original runtime options and historical
permutation reference. Use its seed procedure, batch size, initial learning
rate, drop factor/period, double CB data, single learnables and 164 epochs.
Assert the known historical values rather than silently substituting defaults.
No output from diagnosis may alter these settings.

Adam starts with empty first/second moments and iteration zero, following
the historical per-fit initialization. This is a new optimization phase,
not restoration of an unavailable original Adam state. Use the original
adamupdate call/defaults. Mask hidden gradients and zero all output gradients
before Adam. Verify output coefficients are unchanged before remasking, then
reapply the original masks. Compare every epoch permutation to the stored
historical permutation and verify the final RNG against its reference.

A brief deterministic synthetic run uses the same update loop. Check actual
nonzero raw output gradients are prevented from changing output weights/biases,
pruned entries stay zero, only allowed hidden parameters change, predictions
stay finite, the mixed loss is correct, and the schedule/permutations agree.
Synthetic setup restores the caller RNG. It is not an additional real fit.

Save unique checkpoints at epochs 41, 82 and 123 and the final model at 164,
including new Adam moments, iteration and RNG. Log each epoch's sample-weighted
online minibatch loss, rate, update count and duration. The online loss uses
changing parameters; do not describe it as an end-of-epoch frozen loss.
Do not evaluate/select an epoch using the development complement. Retain the
final epoch even if it is worse. A persistent started marker prohibits reruns.

## Analysis and decision

Compare frozen mixed, LS baseline, final hidden continuation and PN-IQ using
the same identification/complement/full rows and previous metric definitions.
Reuse stored amplitude-bin order and boundaries. Report physical I/Q MSE,
mixed losses, MAE, magnitude/energy-weighted phase error, full RMS/PAPR,
activation distributions, endpoint gradients, parameter counts and FLOPs.

Predeclared descriptive criterion relative to the LS baseline: development
NMSE gain >=0.10 dB and physical Q-MSE increase <=10%. This is not statistical
significance. No follow-up fit, changed duration or variant is authorized.
All data remain development data; no independent generalization, intrinsic
capacity limit or RF improvement may be inferred.
