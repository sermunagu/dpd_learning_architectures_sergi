root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
folders=dir(fullfile(root,'results','dpd_sweep','*','sweep_dense_source.mat'));
for i=1:numel(folders)
    directory=folders(i).folder;
    fprintf('\nSWEEP %s\n',directory);
    S=load(fullfile(directory,'experiment.mat'),'cfg','provenance','split');
    D=load(fullfile(directory,'sweep_dense_source.mat'),'denseSource');
    disp(S.provenance); disp(D.denseSource.runtimeConfig);
    fprintf('Fine epochs=%g, train rows=%g, seed=%g, verbose=%g\n',D.denseSource.fineTuneEpochs,numel(S.split.identificationIndices),S.cfg.pnnn.nnSeed,S.cfg.training.verbose);
    for P=[100 310 400]
        f=fullfile(directory,sprintf('pnnn_target_%04d.mat',P));
        fprintf('P%d checkpoint=%d\n',P,isfile(f));
    end
end