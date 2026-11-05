function checks = checkReadoutSynthetic()
% CHECKREADOUTSYNTHETIC Test the real readout helper on a known small problem.
% No inputs. Returns numerical errors and restores the entry RNG state.
    state = rng; restore = onCleanup(@() rng(state));
    layers = [featureInputLayer(3,Name="input"); ...
        fullyConnectedLayer(4,Name="fc1",WeightsInitializer="zeros",BiasInitializer="zeros"); ...
        sigmoidLayer(Name="sigmoid1"); ...
        fullyConnectedLayer(2,Name="fcOut",WeightsInitializer="zeros",BiasInitializer="zeros")];
    net = dlnetwork(layers); L = net.Learnables;
    W = single([.4 -.7 0;.3 .8 -.2;-.6 .2 .9;.5 -.4 .7]);
    b = single([.1;-.2;.3;-.4]);
    V = single([.2 0 -.3 .4;0 -.1 .5 -.2]); bo = single([.03;-.07]);
    values = {W;b;V;bo}; masks = cellfun(@(v) v~=0,values,'UniformOutput',false);
    for k=1:4, L.Value{k}=dlarray(values{k}); end
    net.Learnables = L;
    q = (1:43).'; Z = [sin(q*.37),cos(q*.73),sin(q*1.19)];
    H = predict(net,Z,Outputs="sigmoid1"); yn = predict(net,Z);
    manualH = 1./(1+exp(-(Z*double(W).'+double(b).')));
    checks.activationMaxAbs = max(abs(double(H)-manualH),[],'all');
    manual = double(H)*double(V).'+double(bo).';
    checks.originalReadoutRelativeL2 = norm(manual-double(yn),'fro')/norm(double(yn),'fro');
    assert(checks.activationMaxAbs<1e-6 && checks.originalReadoutRelativeL2<1e-6);
    referenceV = single([.125 0 -.25 .375;0 -.5 .625 .25]);
    referenceB = single([.0625;-.125]);
    target = double(H)*double(referenceV).'+double(referenceB).';
    [updated,fit] = solveMaskedReadoutLS(net,H,target,masks,[1.41775807004113 .582241929958871]);
    reference = [double(referenceV(1,[1 3 4])).';double(referenceB(1)); ...
        double(referenceV(2,[2 3 4])).';double(referenceB(2))];
    checks.solutionMaxAbs = max(abs(fit.coefficients.DoubleLS-reference));
    assert(checks.solutionMaxAbs<1e-10 && all(fit.summary.Rank==4));
    assert(isequal(updated.Learnables.Value(1:2),net.Learnables.Value(1:2)));
    assert(isequal(predict(updated,Z,Outputs="sigmoid1"),H));
    for k=1:4
        v=extractdata(updated.Learnables.Value{k});
        assert(isa(v,'single') && all(v(~masks{k})==0));
    end
    yp = predict(updated,Z); u = updated.Learnables;
    manual = double(H)*double(extractdata(u.Value{3})).'+double(extractdata(u.Value{4})).';
    checks.updatedReadoutRelativeL2 = norm(manual-double(yp),'fro')/norm(double(yp),'fro');
    mu = [.1 -.02]; sigma = [.3 .4]; r = exp(-1i*q*.13);
    physical = yp.*sigma+mu;
    prediction = conj(r).*complex(physical(:,1),physical(:,2));
    restored = r.*double(prediction);
    checks.phaseRestorationMaxAbs = max(abs(restored-complex(double(physical(:,1)),double(physical(:,2)))));
    expected = conj(r).*complex(target(:,1)*sigma(1)+mu(1),target(:,2)*sigma(2)+mu(2));
    checks.knownPredictionRelativeL2 = norm(double(prediction)-expected)/norm(expected);
    assert(checks.updatedReadoutRelativeL2<1e-6 && checks.phaseRestorationMaxAbs<1e-6);
    assert(checks.knownPredictionRelativeL2<1e-6);
    checks.rank = fit.summary.Rank; checks.coefficientCastMaxAbs = fit.summary.CoefficientCastMaxAbs;
    checks.hiddenWeightsExact = true; checks.masksExact = true;
    checks.hiddenActivationsExact = true; checks.weightsCancelAnalytically = true;
    disp(checks); fprintf('SYNTHETIC READOUT CHECKS PASS.\n');
end
