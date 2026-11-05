function result = diagnoseHiddenGradient(model, X, target, weights, batchSize, finiteCheck)
% DIAGNOSEHIDDENGRADIENT Evaluate frozen identification gradients in fixed order.
% Inputs: model, original normalized identification rows, weights, batch size,
% and whether to run the initial double finite-difference consistency check.
% Output: sample-weighted native AD gradients, summaries and optional checks.
    beforeRng=rng; original=model.network.Learnables; state=model.network.State;
    [loss,g]=aggregate(model.network,X,target,weights,batchSize);
    stats=table(); neurons=table(); selections=["active","pruned","all"];
    for k=1:height(original)
        mask=model.masks{k}; value=double(extractdata(original.Value{k}));
        for selection=selections
            if selection=="active", ix=mask; elseif selection=="pruned", ix=~mask; else, ix=true(size(mask)); end
            v=g{k}(ix); a=sort(abs(v));
            if isempty(a), maximum=0; medianValue=0; p95=0; meanValue=0;
            else, maximum=a(end); medianValue=median(a); p95=a(ceil(.95*numel(a))); meanValue=mean(a); end
            row=table(string(original.Layer(k)),string(original.Parameter(k)),selection,numel(v), ...
                norm(v),maximum,meanValue,medianValue,p95,norm(value(ix)), ...
                'VariableNames',{'Layer','Parameter','Selection','Count','L2','MaxAbs','MeanAbs','MedianAbs','P95Abs','ParameterL2'});
            stats=[stats;row]; %#ok<AGROW>
        end
    end
    for n=1:size(g{1},1)
        active=g{1}(n,model.masks{1}(n,:)); pruned=g{1}(n,~model.masks{1}(n,:));
        neurons=[neurons;table(n,numel(active),norm(active),norm(pruned),max(abs(active)),g{2}(n), ...
            norm([active(:);g{2}(n)]),'VariableNames',{'Neuron','ActiveInputs','ActiveWeightL2', ...
            'PrunedWeightL2','ActiveWeightMaxAbs','BiasGradient','ActiveHiddenL2'})]; %#ok<AGROW>
    end
    result=struct('loss',loss,'gradients',{g},'statistics',stats,'neurons',neurons, ...
        'hiddenActiveL2',norm([g{1}(model.masks{1});g{2}(model.masks{2})]), ...
        'hiddenPrunedL2',norm(g{1}(~model.masks{1})), ...
        'outputPermittedL2',norm([g{3}(model.masks{3});g{4}(model.masks{4})]), ...
        'outputPrunedL2',norm(g{3}(~model.masks{3})));
    if finiteCheck
        doubleNet=model.network; L=original;
        for k=1:height(L), L.Value{k}=dlarray(double(extractdata(L.Value{k}))); end
        doubleNet.Learnables=L;
        [doubleLoss,gd]=aggregate(doubleNet,X,target,weights,batchSize);
        nativePrediction=double(predict(model.network,X)); doublePrediction=predict(doubleNet,X);
        relativePrediction=norm(nativePrediction-doublePrediction,'fro')/norm(doublePrediction,'fro');
        assert(relativePrediction<=1e-6);
        comparison=table();
        for k=1:height(L)
            difference=norm(g{k}(:)-gd{k}(:)); bound=1e-6+1e-3*norm(gd{k}(:));
            assert(difference<=bound,'Native/double AD inconsistency.');
            comparison=[comparison;table(string(L.Layer(k)),string(L.Parameter(k)),difference,bound, ...
                max(abs(g{k}-gd{k}),[],'all'),'VariableNames',{'Layer','Parameter','L2Difference','Bound','MaxAbsDifference'})]; %#ok<AGROW>
        end
        differences=table();
        for n=[1 6 12]
            feature=find(model.masks{1}(n,:),1,'first');
            for k=1:2
                if k==1, index=sub2ind(size(g{1}),n,feature); else, index=n; end
                value=extractdata(L.Value{k}); theta=value(index);
                h=eps^(1/3)*max(1,abs(theta)); plus=L; minus=L;
                vp=value; vm=value; vp(index)=theta+h; vm(index)=theta-h;
                plus.Value{k}=dlarray(vp); minus.Value{k}=dlarray(vm);
                plusNet=doubleNet; minusNet=doubleNet;
                plusNet.Learnables=plus; minusNet.Learnables=minus;
                fp=mean((predict(plusNet,X)-target).^2.*weights,'all');
                fm=mean((predict(minusNet,X)-target).^2.*weights,'all');
                fd=(fp-fm)/(2*h); ad=gd{k}(index); native=g{k}(index);
                tolerance=1e-8+1e-4*abs(ad); assert(abs(fd-ad)<=tolerance,'Finite difference mismatch.');
                differences=[differences;table(string(L.Parameter(k)),n,index,h,native,ad,fd,abs(fd-ad), ...
                    tolerance,abs(native-fd),'VariableNames',{'Parameter','Neuron','LinearIndex','Step', ...
                    'NativeAD','DoubleAD','FiniteDifference','DoubleAbsError','Bound','NativeAbsError'})]; %#ok<AGROW>
            end
        end
        assert(result.outputPermittedL2<=1e-5,'Permitted LS readout gradient is not small.');
        result.doubleCheck=struct('loss',doubleLoss,'predictionRelativeL2',relativePrediction, ...
            'gradientComparison',comparison,'finiteDifferences',differences);
    end
    assert(isequal(original,model.network.Learnables) && isequal(state,model.network.State));
    assert(isequal(beforeRng,rng)); result.rngExact=true; result.weightsExact=true;
end

function [loss,g]=aggregate(network,X,target,weights,batchSize)
% Sum native minibatch means using double accumulation and sample weights.
    N=size(X,1); L=network.Learnables; g=cell(height(L),1); loss=0;
    for k=1:height(L), g{k}=zeros(size(extractdata(L.Value{k})),'double'); end
    for first=1:batchSize:N
        ix=first:min(first+batchSize-1,N);
        [batchLoss,gradients]=dlfeval(@hiddenLoss,network,dlarray(X(ix,:).','CB'), ...
            dlarray(target(ix,:).','CB'),weights);
        scale=numel(ix)/N; loss=loss+scale*double(extractdata(batchLoss));
        for k=1:height(L)
            value=double(extractdata(gradients.Value{k})); assert(all(isfinite(value),'all'));
            g{k}=g{k}+scale*value;
        end
    end
    assert(isfinite(loss));
end
