function [loss, gradients] = hiddenLoss(network, dlX, dlTarget, weights)
% HIDDENLOSS Evaluate the unchanged mixed loss and all raw parameter gradients.
% Inputs: network, CB normalized arrays, fixed channel weights. Outputs: AD.
    prediction=forward(network,dlX);
    loss=weightedLoss(prediction,dlTarget,weights);
    gradients=dlgradient(loss,network.Learnables);
end
