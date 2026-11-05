# Locked mixed-loss experiment

One real P310 fit, alpha=0.5, 164 fixed epochs, from the October saved dense
source. The full-precision physical weights saved in pnnn_loss_experiment
are used, not the rounded display values. No acceleration, architecture,
mask, preprocessing, optimizer, seed, epoch or learning-rate changes.
The prior diagnostic lossPrunePNNN and weightedLoss helpers are reused
without edits; there is no second training-loop implementation here.

Before training, check the mixed scalar loss against 0.5*Lnorm+0.5*Lfis,
analytic gradients, central finite differences and prediction-precision
behavior. Reconstruct the masked initial network with zero updates, compare
it exactly to the previous saved initialization, and replay/compare all
164 saved minibatch permutations. No previous real fit is repeated.

Interpretation rule fixed before observing the new fit, from the preceding
pnnn_loss_validation report: on the development complement require >=0.10 dB
NMSE improvement over historical and <=10% increase of physical Q MSE.
These are engineering thresholds, not statistical or RF criteria. Report
all metrics, including adverse amplitude, angular and signal changes.
Regardless of pass/fail, no extra alpha, seed, epoch or hyperparameter trial
is authorized. References alpha=0, alpha=1 and PN-IQ-GMP are frozen.

All evaluation uses development data. No independent generalization or RF
benefit may be inferred. Final comparison will distinguish an attractive
tradeoff from evidence that loss choice closes the PN-IQ/PNNN gap.
