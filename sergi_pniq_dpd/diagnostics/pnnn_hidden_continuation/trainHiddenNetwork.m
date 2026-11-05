function [network, training] = trainHiddenNetwork(network, masks, X, target, settings, orders, checkpointFolder)
% TRAINHIDDENNETWORK Continue only permitted fc1 entries with historical Adam.
% Inputs: frozen-source network/masks, normalized rows, original settings,
% expected permutations and optional unique checkpoint folder (empty for test).
% Outputs: final network and trace/new optimizer state. No epoch selection.
    frozen=network.Learnables; N=size(X,1);
    assert(isequal(size(orders),[N settings.epochs]));
    rng(settings.seed,'twister'); initialRng=rng;
    average=[]; averageSquared=[]; iteration=0;
    trace=table(); firstLoss=NaN; firstRawOutputNorm=NaN; timer=tic;
    for epoch=1:settings.epochs
        epochTimer=tic; order=randperm(N);
        assert(isequal(uint32(order(:)),orders(:,epoch)),'Historical permutation mismatch.');
        learnRate=settings.initialLearnRate*settings.dropFactor^floor((epoch-1)/max(settings.dropPeriod,1));
        onlineLoss=0;
        for first=1:settings.batchSize:N
            batch=order(first:min(first+settings.batchSize-1,N));
            [loss,g]=dlfeval(@hiddenLoss,network,dlarray(X(batch,:).','CB'), ...
                dlarray(target(batch,:).','CB'),settings.weights);
            if iteration==0
                firstLoss=double(extractdata(loss));
                firstRawOutputNorm=norm([double(extractdata(g.Value{3}(:)));double(extractdata(g.Value{4}(:)))]);
            end
            for k=1:height(g)
                assert(all(isfinite(extractdata(g.Value{k})),'all'));
                if k<=2, g.Value{k}=g.Value{k}.*cast(masks{k},'like',extractdata(g.Value{k}));
                else, g.Value{k}=g.Value{k}.*0; end
            end
            iteration=iteration+1;
            [network,average,averageSquared]=adamupdate(network,g,average,averageSquared,iteration,learnRate);
            % Check before remasking so restoration cannot hide an output update.
            assert(isequal(network.Learnables.Value(3:4),frozen.Value(3:4)));
            L=network.Learnables;
            for k=1:height(L)
                L.Value{k}=L.Value{k}.*cast(masks{k},'like',extractdata(L.Value{k}));
            end
            network.Learnables=L;
            onlineLoss=onlineLoss+double(extractdata(loss))*numel(batch)/N;
        end
        assert(isequal(network.Learnables.Value(3:4),frozen.Value(3:4)));
        for k=1:height(frozen)
            value=extractdata(network.Learnables.Value{k});
            assert(all(value(~masks{k})==0) && nnz(value)==nnz(masks{k}));
        end
        trace=[trace;table(epoch,iteration,learnRate,onlineLoss,toc(epochTimer), ...
            'VariableNames',{'Epoch','Updates','LearnRate','OnlineMeanBatchLoss','Seconds'})]; %#ok<AGROW>
        fprintf('Epoch %d/%d | updates %d | LR %.10g | online mixed loss %.12g | %.3f s\n', ...
            epoch,settings.epochs,iteration,learnRate,onlineLoss,trace.Seconds(end));
        if strlength(string(checkpointFolder))>0 && ismember(epoch,[41 82 123])
            file=fullfile(checkpointFolder,sprintf('checkpoint_epoch%04d.mat',epoch));
            assert(~isfile(file)); checkpointRng=rng;
            save(file,'network','masks','settings','average','averageSquared','iteration','epoch','checkpointRng','trace','-v7.3');
        end
    end
    training=struct('trace',trace,'average',average,'averageSquared',averageSquared, ...
        'iterations',iteration,'initialRng',initialRng,'finalRng',rng,'seconds',toc(timer), ...
        'firstLoss',firstLoss,'firstRawOutputNorm',firstRawOutputNorm, ...
        'everyOutputUpdateExact',true,'everyOrderExact',true,'momentsInitializedEmpty',true);
end
