function checks = testHiddenUpdates(settings)
% TESTHIDDENUPDATES Exercise the real update loop on a small synthetic problem.
% Input: recovered real settings. Output: tests; restores caller RNG state.
    state=rng; restore=onCleanup(@() rng(state));
    layers=[featureInputLayer(3,Name="input"); ...
        fullyConnectedLayer(4,Name="fc1",WeightsInitializer="zeros",BiasInitializer="zeros"); ...
        sigmoidLayer(Name="sigmoid1"); ...
        fullyConnectedLayer(2,Name="fcOut",WeightsInitializer="zeros",BiasInitializer="zeros")];
    network=dlnetwork(layers); L=network.Learnables;
    values={single([.4 -.7 0;.3 .8 -.2;-.6 .2 .9;.5 -.4 .7]); ...
        single([.1;-.2;.3;-.4]);single([.2 0 -.3 .4;0 -.1 .5 -.2]);single([.03;-.07])};
    masks=cellfun(@(v)v~=0,values,'UniformOutput',false);
    for k=1:4, L.Value{k}=dlarray(values{k}); end
    network.Learnables=L;
    N=settings.batchSize+3; q=(1:N).'; X=[sin(q*.37),cos(q*.73),sin(q*1.19)];
    target=[.2*sin(q*.17),.3*cos(q*.23)];
    s=settings; s.epochs=2;
    rng(s.seed,'twister'); orders=zeros(N,s.epochs,'uint32');
    for epoch=1:s.epochs, orders(:,epoch)=uint32(randperm(N)).'; end
    expectedRng=rng;
    firstBatch=double(orders(1:s.batchSize,1));
    y=forward(network,dlarray(X(firstBatch,:).','CB'));
    manual=mean(cast(s.weights(:),'like',extractdata(y)).*(extractdata(y)-target(firstBatch,:).').^2,'all');
    [updated,training]=trainHiddenNetwork(network,masks,X,target,s,orders,'');
    checks.lossAbsError=abs(training.firstLoss-double(manual)); assert(checks.lossAbsError<1e-7);
    assert(training.firstRawOutputNorm>1e-5);
    assert(isequal(updated.Learnables.Value(3:4),network.Learnables.Value(3:4)));
    assert(~isequal(updated.Learnables.Value(1:2),network.Learnables.Value(1:2)));
    for k=1:4, value=extractdata(updated.Learnables.Value{k}); assert(all(value(~masks{k})==0)); end
    assert(all(isfinite(predict(updated,X)),'all') && isequal(training.finalRng,expectedRng));
    epochs=[1 41 42 82 83 123 124 164];
    rates=settings.initialLearnRate*settings.dropFactor.^floor((epochs-1)/settings.dropPeriod);
    expected=settings.initialLearnRate*settings.dropFactor.^[0 0 1 1 2 2 3 3];
    assert(isequal(rates,expected));
    assert(training.iterations==4 && all(training.trace.LearnRate==settings.initialLearnRate));
    checks.rawOutputGradientNorm=training.firstRawOutputNorm; checks.outputExact=true;
    checks.onlyAllowedHiddenChanges=true; checks.prunedZerosExact=true; checks.ordersExact=true;
    checks.rngMatchesExpected=true; checks.scheduleEpochs=epochs; checks.scheduleRates=rates;
    checks.syntheticUpdates=training.iterations; disp(checks); fprintf('SYNTHETIC UPDATE TEST PASS.\n');
end
