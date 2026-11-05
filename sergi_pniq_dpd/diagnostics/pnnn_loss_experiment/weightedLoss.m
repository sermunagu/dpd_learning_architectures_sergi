function loss = weightedLoss(prediction, target, weights)
% WEIGHTEDLOSS Weighted I/Q MSE on 2-by-batch CB normalized tensors.
% Weights are constants in the prediction precision; output is scalar.
assert(size(prediction,1)==2 && isequal(size(prediction),size(target)));
w=dlarray(cast(weights(:),'like',extractdata(prediction)),"CB");
loss=mean(w.*(prediction-target).^2,"all");
end
