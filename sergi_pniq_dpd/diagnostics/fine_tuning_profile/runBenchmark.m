function runBenchmark()
% RUNBENCHMARK Profile saved-source fixed-epoch fine-tuning without optimization.
% No inputs. Writes a unique diagnostic run below this folder, never results/.
    here = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(here));
    originalPath = path;
    cleanup = onCleanup(@() path(originalPath));
    addpath(here,genpath(fullfile(root,'toolbox')));
    directory = fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
    out = tempname(here); mkdir(out);
    fprintf('Diagnostic output: %s\n',out);
    t=tic; S=load(fullfile(directory,'experiment.mat'));
    D=load(fullfile(directory,'sweep_dense_source.mat'),'denseSource');
    loadingSeconds=toc(t);
    denseSource=D.denseSource;
    denseSource.runtimeConfig.training.verbose=S.cfg.training.verbose;
    assert(~isa(extractdata(denseSource.denseFit.network.Learnables.Value{1}),'gpuArray'), ...
        'This diagnostic uses CPU wall timers; GPU requires synchronization.');
    t=tic;
    [features,targets,rotation]=buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
    features=features.'; targets=targets.'; rotation=rotation(:);
    featureSeconds=toc(t);
    options=struct('Mode',"fixed-epochs",'TrainingRows',S.split.identificationIndices, ...
        'ValidationRows',[],'NNSeed',S.cfg.pnnn.nnSeed,'FineTuneEpochs',denseSource.fineTuneEpochs, ...
        'Config',denseSource.runtimeConfig);
    environment=struct('version',version,'computer',computer,'processor',getenv('PROCESSOR_IDENTIFIER'), ...
        'threads',maxNumCompThreads,'featuresClass',class(features),'targetsClass',class(targets), ...
        'learnableClass',class(extractdata(denseSource.denseFit.network.Learnables.Value{1})), ...
        'sourceDirectory',directory,'loadingSeconds',loadingSeconds,'featureSeconds',featureSeconds, ...
        'trainingRows',numel(options.TrainingRows),'epochs',options.FineTuneEpochs, ...
        'batchSize',options.Config.training.miniBatchSize,'config',options.Config);
    save(fullfile(out,'environment.mat'),'environment'); disp(environment);
    summary=table();
    for P=[100 310 400]
        fprintf('Starting instrumented P%d, full %d epochs\n',P,options.FineTuneEpochs);
        options.TargetActiveParameters=P;
        t=tic; result=timedPrunePNNN(denseSource.denseFit,features,targets,options); total=toc(t);
        finalRng=rng;
        saved=load(fullfile(directory,sprintf('pnnn_target_%04d.mat',P)),'point');
        equalCheckpoint=isequal(result.network.Learnables,saved.point.model.network.Learnables) && ...
            isequal(result.masks,saved.point.model.masks);
        maxDifference=0;
        for k=1:height(result.network.Learnables)
            a=extractdata(result.network.Learnables.Value{k}); b=extractdata(saved.point.model.network.Learnables.Value{k});
            maxDifference=max(maxDifference,max(abs(double(a(:))-double(b(:)))));
        end
        t=tic; stats=denseSource.denseFit.normalization; rows=S.split.identificationIndices;
        fi=(features(rows,:)-stats.muX)./stats.sigmaX;
        ff=(features- stats.muX)./stats.sigmaX;
        yi=predictPNNN(result.network,fi,stats,rotation(rows));
        yf=predictPNNN(result.network,ff,stats,rotation);
        identificationNMSE=nmseComplexDb(S.y(rows),yi); fullNMSE=nmseComplexDb(S.y,yf);
        predictionSeconds=toc(t);
        predictionEqual=isequal(yf,saved.point.fullSignalPrediction);
        diagnostic=result.diagnostic; totals=sum(diagnostic.steps,1);
        row=table(P,total,totals(1),totals(2),totals(3),totals(4),totals(5), ...
            total-sum(totals),predictionSeconds,equalCheckpoint,maxDifference,predictionEqual,identificationNMSE,fullNMSE, ...
            'VariableNames',{'P','TotalSeconds','MinibatchSeconds','DlfevalSeconds','GradientMaskSeconds', ...
            'AdamSeconds','WeightMaskSeconds','OtherSeconds','PredictionSeconds','EqualCheckpoint', ...
            'MaxParameterDifference','PredictionEqual','IdentificationNMSE','FullNMSE'});
        summary=[summary;row]; %#ok<AGROW>
        writetable(summary,fullfile(out,'summary.csv'));
        writematrix(diagnostic.steps,fullfile(out,sprintf('steps_P%d.csv',P)));
        save(fullfile(out,sprintf('timing_P%d.mat',P)),'diagnostic','row','finalRng');
        disp(row);
        if P==310
            t=tic; baseline=pruneAndFineTunePNNN(denseSource.denseFit,features,targets,options); baselineSeconds=toc(t);
            exactInstrumentation=isequal(baseline.network.Learnables,result.network.Learnables) && ...
                isequal(baseline.masks,result.masks) && isequal(rng,finalRng);
            assert(exactInstrumentation,'Diagnostic instrumentation changed the numerical procedure.');
            save(fullfile(out,'baseline_P310.mat'),'baselineSeconds','exactInstrumentation');
            fprintf('Uninstrumented P310 %.3f s, exact instrumentation match %d\n',baselineSeconds,exactInstrumentation);
        end
        clear result baseline saved ff fi yf yi
    end
    % Supplemental one-epoch call-tree profile, separate from full-run timings.
    options.TargetActiveParameters=310; options.FineTuneEpochs=1;
    profile clear; profile on;
    pruneAndFineTunePNNN(denseSource.denseFit,features,targets,options);
    profile off; profileInfo=profile('info');
    save(fullfile(out,'call_tree_one_epoch.mat'),'profileInfo');
    fprintf('BENCHMARK COMPLETE: %s\n',out);
end
