function [network, fit] = solveMaskedReadoutLS(network, H, target, masks, weights)
% SOLVEMASKEDREADOUTLS Fit only mask-permitted output coefficients by SVD.
% Inputs: frozen network, identification activations/targets, masks, weights.
% Outputs: copied network with original-precision readout and solve evidence.
% Exactly one SVD coefficient solve per output; no normal-equation solve.
    L = network.Learnables;
    iw = find(string(L.Layer)=="fcOut" & string(L.Parameter)=="Weights");
    ib = find(string(L.Layer)=="fcOut" & string(L.Parameter)=="Bias");
    assert(isscalar(iw) && isscalar(ib));
    oldW = extractdata(L.Value{iw}); oldB = extractdata(L.Value{ib});
    assert(size(H,2)==size(oldW,2) && isequal(size(target),[size(H,1),2]));
    assert(all(masks{ib},'all') && all(oldW(~masks{iw})==0));
    H = double(H); target = double(target); N = size(H,1);
    assert(all(isfinite(H),'all') && all(isfinite(target),'all'));
    assert(numel(weights)==2 && all(weights>0));
    newW = zeros(size(oldW),'like',oldW); newB = oldB;
    fit.coefficients = table(); fit.summary = table(); fit.outputs = cell(2,1);
    for c = 1:2
        keep = find(masks{iw}(c,:));
        A = [H(:,keep),ones(N,1)]; t = target(:,c);
        timer = tic;
        [U,S,V] = svd(A,0); singular = diag(S);
        tolerance = max(size(A))*eps(singular(1));
        retained = singular>tolerance; effectiveRank = nnz(retained);
        assert(effectiveRank>0);
        beta = V(:,retained)*((U(:,retained).'*t)./singular(retained));
        seconds = toc(timer);
        betaStored = cast(beta,'like',oldW);
        assert(all(abs(double(betaStored)-beta)<=double(eps(class(oldW)))*abs(beta)+realmin));
        newW(c,keep) = betaStored(1:end-1); newB(c) = betaStored(end);
        oldBeta = [double(oldW(c,keep)).';double(oldB(c))];
        eOld = A*oldBeta-t; eDouble = A*beta-t; eCast = A*double(betaStored)-t;
        cosine = @(e) max(abs(A.'*e)./(sqrt(sum(A.^2,1)).'*norm(e)));
        relativeNE = @(e) norm(A.'*e)/(norm(A,'fro')*max(norm(t),norm(e)));
        scaledSingular = svd(A./sqrt(sum(A.^2,1)),0);
        assert(relativeNE(eDouble)<1e-10);
        if effectiveRank==size(A,2)
            assert(mean(eDouble.^2)<=mean(eOld.^2)+100*eps*max(1,mean(eOld.^2)));
        end
        castDelta = A*(double(betaStored)-beta);
        fit.summary = [fit.summary;table(c,N,numel(beta),effectiveRank,tolerance, ...
            singular(1)/singular(end),scaledSingular(1)/scaledSingular(end), ...
            mean(eOld.^2),mean(eDouble.^2),mean(eCast.^2), ...
            cosine(eOld),cosine(eDouble),cosine(eCast), ...
            relativeNE(eOld),relativeNE(eDouble),relativeNE(eCast), ...
            norm(weights(c)*A.'*eOld/N),norm(weights(c)*A.'*eDouble/N), ...
            norm(weights(c)*A.'*eCast/N),max(abs(double(betaStored)-beta)), ...
            norm(double(betaStored)-beta)/norm(beta),norm(castDelta)/norm(A*beta),seconds, ...
            'VariableNames',{'Output','N','Columns','Rank','RankTolerance','RawCondition', ...
            'ColumnScaledCondition','OldNormalizedMSE','DoubleNormalizedMSE','CastNormalizedMSE', ...
            'OldMaxCosine','DoubleMaxCosine','CastMaxCosine','OldRelativeNE','DoubleRelativeNE', ...
            'CastRelativeNE','OldGradientNorm','DoubleGradientNorm','CastGradientNorm', ...
            'CoefficientCastMaxAbs','CoefficientCastRelativeL2','PredictionCastRelativeL2','SolveSeconds'})]; %#ok<AGROW>
        fit.coefficients = [fit.coefficients;table(repmat(c,numel(beta),1),[keep(:);0], ...
            oldBeta,beta,double(betaStored),double(betaStored)-oldBeta, ...
            'VariableNames',{'Output','NeuronZeroMeansBias','Original','DoubleLS','StoredLS','Change'})]; %#ok<AGROW>
        fit.outputs{c} = struct('keep',keep,'beta',beta,'betaStored',betaStored, ...
            'singularValues',singular,'scaledSingularValues',scaledSingular, ...
            'rankTolerance',tolerance,'rank',effectiveRank);
    end
    L.Value{iw} = dlarray(newW); L.Value{ib} = dlarray(newB);
    network.Learnables = L;
    fit.outputWeightRow = iw; fit.outputBiasRow = ib; fit.weights = weights;
end
