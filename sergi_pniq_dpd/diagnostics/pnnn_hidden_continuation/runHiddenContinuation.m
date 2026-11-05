function out = runHiddenContinuation(mode, out)
% RUNHIDDENCONTINUATION Diagnose, validate and run one hidden-only continuation.
% Use ('preflight'), then ('train',runFolder). Historical files remain read-only.
% Outputs are confined to a new unique folder; a started real fit cannot repeat.
    here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
    oldPath=path; restorePath=onCleanup(@() path(oldPath));
    addpath(here,genpath(fullfile(root,'toolbox')),fullfile(root,'diagnostics','pnnn_loss_experiment'));
    if nargin<1, mode="preflight"; end
    if string(mode)=="preflight"
        assert(isempty(dir(fullfile(here,'*','training_started.mat'))),'A real continuation was already started.');
        assert(isempty(dir(fullfile(here,'*','preflight.mat'))),'Use the existing preflight.');
        out=tempname(here); mkdir(out); diary(fullfile(out,'preflight.log')); dc=onCleanup(@() diary('off'));
        files=dir(fullfile(here,'*.m'));
        for k=1:numel(files)
            fprintf('CHECKCODE %s\n',files(k).name); disp(checkcode(fullfile(here,files(k).name),'-id'));
        end
        beforeRng=rng;
        source.lsFolder=fullfile(root,'diagnostics','pnnn_readout_ls','tp927d59fa_d1a5_4040_a786_7820557ca62f');
        source.model=fullfile(source.lsFolder,'readout_model.mat');
        source.prediction=fullfile(source.lsFolder,'inference.mat');
        source.cache=fullfile(source.lsFolder,'prepared.mat');
        assert(isfile(source.model) && isfile(source.prediction) && isfile(source.cache));
        F=load(source.model); I=load(source.prediction);
        Q=load(source.cache,'Z','target','r','id','dev','model','provenance');
        originalSource=F.provenance.source; source.mixedProtocol=originalSource.protocol;
        P=load(source.mixedProtocol); source.permutations=P.provenance.previousProtocol;
        R=load(source.permutations,'orders','expectedRng','provenance');
        S=load(originalSource.experiment); raw=load(originalSource.capture);
        assert(contains(string(originalSource.capture),'20261023T102742'));
        assert(isequal(double(raw.x(:))-mean(double(raw.x(:))),S.x));
        assert(isequal(double(raw.y(:))-mean(double(raw.y(:))),S.y)); clear raw
        model=F.model; options=P.provenance.options; cfg=options.Config;
        assert(isequal(model.normalization,Q.model.normalization,P.provenance.normalization));
        assert(isequal(model.masks,Q.model.masks) && isequal(model.featureConfig,Q.model.featureConfig));
        assert(isequal(model.network.Learnables.Value(1:2),Q.model.network.Learnables.Value(1:2)));
        assert(isequal(Q.id,S.split.identificationIndices,options.TrainingRows));
        assert(isequal(Q.dev,S.split.evaluationIndices));
        assert(size(Q.Z,2)==84 && size(Q.target,2)==2 && numel(Q.id)==49151 && numel(Q.dev)==442369);
        assert(isa(Q.Z,'double') && isa(Q.target,'double'));
        prediction=predictPNNN(model.network,Q.Z,model.normalization,Q.r);
        assert(isequal(prediction,I.prediction),'STOP: source LS inference mismatch.'); clear prediction
        assert(isequal(cellfun(@nnz,model.masks),[273;12;23;2]));
        L=model.network.Learnables;
        assert(isequal(string(L.Layer),["fc1";"fc1";"fcOut";"fcOut"]));
        for k=1:4
            value=extractdata(L.Value{k}); assert(isa(value,'single') && nnz(value)==nnz(model.masks{k}));
            assert(all(value(~model.masks{k})==0));
        end
        settings=struct('epochs',double(options.FineTuneEpochs), ...
            'seed',double(options.NNSeed)+double(cfg.pruning.fineTuneSeedOffset), ...
            'batchSize',cfg.training.miniBatchSize,'initialLearnRate',cfg.pruning.fineTuneInitialLearnRate, ...
            'dropFactor',cfg.training.learnRateDropFactor,'dropPeriod',cfg.pruning.fineTuneLearnRateDropPeriod, ...
            'weights',P.provenance.weights,'optimizer',string(S.cfg.training.optimizer), ...
            'inputFormat','CB','targetFormat','CB','useAcceleration',false);
        assert(settings.epochs==164 && settings.seed==100042 && settings.batchSize==1024);
        assert(settings.initialLearnRate==2e-4 && settings.dropFactor==.95 && settings.dropPeriod==41);
        assert(settings.optimizer=="adam" && string(S.cfg.training.shuffle)=="every-epoch");
        assert(string(S.cfg.training.executionEnvironment)=="cpu" && ~cfg.pruning.useAcceleration);
        assert(settings.batchSize==S.cfg.training.miniBatchSize && settings.dropFactor==S.cfg.training.learnRateDropFactor);
        assert(isequal(settings.weights,F.provenance.weights,options.LossWeights) && P.provenance.alpha==.5);
        assert(isequal(size(R.orders),[numel(Q.id),164]) && isequal(R.expectedRng,P.expectedRng));
        rng(settings.seed,'twister');
        for epoch=1:settings.epochs
            assert(isequal(uint32(randperm(numel(Q.id))).',R.orders(:,epoch)));
        end
        assert(isequal(rng,R.expectedRng)); rng(beforeRng);
        provenance=struct('source',source,'originalSource',originalSource,'options',options, ...
            'settings',settings,'matlab',version,'computer',computer,'threads',maxNumCompThreads, ...
            'mixedLossHelper',which('weightedLoss'),'optimizerHelper',which('adamupdate'), ...
            'preparedOn',char(datetime('now')),'expectedRng',R.expectedRng,'alpha',.5, ...
            'optimizerMoments','New empty moments, not an original optimizer-state resume');
        disp(settings);
        diagnostic=diagnoseHiddenGradient(model,Q.Z(Q.id,:),Q.target(Q.id,:),settings.weights,settings.batchSize,true);
        assert(abs(diagnostic.loss-I.verification.identificationLossAfter)<1e-7);
        assert(isequal(F.model.network.Learnables,model.network.Learnables));
        assert(isequal(F.model.masks,model.masks) && isequal(F.model.normalization,model.normalization));
        assert(isequal(beforeRng,rng));
        save(fullfile(out,'gradient_before.mat'),'diagnostic','-v7.3');
        writetable(diagnostic.statistics,fullfile(out,'gradient_before.csv'));
        writetable(diagnostic.neurons,fullfile(out,'gradient_neurons_before.csv'));
        writetable(diagnostic.doubleCheck.finiteDifferences,fullfile(out,'gradient_finite_differences.csv'));
        writetable(diagnostic.doubleCheck.gradientComparison,fullfile(out,'gradient_precision.csv'));
        fprintf('Initial loss %.15g | active hidden gradient %.12g | permitted output %.12g\n', ...
            diagnostic.loss,diagnostic.hiddenActiveL2,diagnostic.outputPermittedL2);
        disp(diagnostic.statistics); disp(diagnostic.doubleCheck.finiteDifferences);
        synthetic=testHiddenUpdates(settings); assert(isequal(beforeRng,rng));
        checks=struct('savedInferenceExact',true,'captureExact',true,'normalizationExact',true, ...
            'masksExact',true,'permutationsExact',true,'gradientReadOnly',true,'rngExact',true, ...
            'initialLossDifference',abs(diagnostic.loss-I.verification.identificationLossAfter));
        save(fullfile(out,'preflight.mat'),'provenance','checks','synthetic','beforeRng','-v7.3');
        fprintf('PREFLIGHT COMPLETE. No real update performed.\n%s\n',out);
    elseif string(mode)=="train"
        assert(nargin==2 && isfile(fullfile(out,'preflight.mat')));
        assert(isempty(dir(fullfile(here,'*','training_started.mat'))),'A real continuation was already started.');
        assert(isempty(dir(fullfile(here,'*','final_model.mat'))),'Use the saved final model.');
        diary(fullfile(out,'training.log')); dc=onCleanup(@() diary('off'));
        P=load(fullfile(out,'preflight.mat')); provenance=P.provenance; settings=provenance.settings;
        F=load(provenance.source.model); Q=load(provenance.source.cache,'Z','target','id');
        R=load(provenance.source.permutations,'orders','expectedRng');
        X=Q.Z(Q.id,:); target=Q.target(Q.id,:); clear Q
        assert(settings.epochs==164 && size(X,1)==49151 && ~settings.useAcceleration);
        beforeRng=rng; save(fullfile(out,'training_started.mat'),'provenance','beforeRng');
        [network,training]=trainHiddenNetwork(F.model.network,F.model.masks,X,target,settings,R.orders,out);
        model=F.model; model.network=network;
        save(fullfile(out,'final_model.mat'),'model','training','provenance','beforeRng','-v7.3');
        assert(training.iterations==7872 && isequal(training.finalRng,R.expectedRng));
        assert(isequal(model.network.Learnables.Value(3:4),F.model.network.Learnables.Value(3:4)));
        assert(isequal(model.normalization,F.model.normalization) && isequal(model.masks,F.model.masks));
        assert(isequal(model.network.Connections,F.model.network.Connections) && isequal(model.network.State,F.model.network.State));
        assert(isequal(model.network.Layers([1 3 4]),F.model.network.Layers([1 3 4])));
        assert(~isequal(model.network.Learnables.Value(1:2),F.model.network.Learnables.Value(1:2)));
        writetable(training.trace,fullfile(out,'training_epochs.csv'));
        fprintf('ONE REAL CONTINUATION COMPLETE: %d updates, %.9f seconds, exact output and RNG.\n%s\n', ...
            training.iterations,training.seconds,out);
    else
        error('Use preflight or train.');
    end
end
