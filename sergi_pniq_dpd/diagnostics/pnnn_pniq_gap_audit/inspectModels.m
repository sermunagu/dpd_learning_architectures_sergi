function inspectModels()
% INSPECTMODELS Read model/configuration metadata and export selected basis.
% No inputs; writes a unique audit folder. No fitting or parameter updates.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
out=tempname(here); mkdir(out); diary(fullfile(out,'inspection.log')); c=onCleanup(@() diary('off'));
folder=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
B=load(fullfile(folder,'models_P0310.mat')); S=load(fullfile(folder,'experiment.mat'));
D=load(fullfile(folder,'sweep_dense_source.mat')); disp(B.bundle); disp(S.cfg.gmp); disp(S.cfg.pnnn);
disp(S.cfg.training); disp(S.cfg.pruning); disp(D.denseSource); disp(D.denseSource.runtimeConfig);
disp(D.denseSource.denseFit); disp(B.bundle.models{3}.network.Layers);
m=B.bundle.models{2}; disp(m); disp(m.descriptors(1));
features=table(); n=numel(m.descriptors);
for j=1:numel(m.selectedColumns)
    col=m.selectedColumns(j); q=col>n; d=m.descriptors(mod(col-1,n)+1);
    degree=sum(d.envelopePowers)+double(d.canonicalGMP || d.auxiliaryType=="conjugate");
    features=[features;table(j,q,d.canonicalGMP,d.carrierLag,string(mat2str(d.envelopeLags)), ...
        string(mat2str(d.envelopePowers)),degree,m.coefficientsI(j),m.coefficientsQ(j), ...
        'VariableNames',{'Feature','IsQ','Canonical','CarrierLag','EnvelopeLags','EnvelopePowers','Degree','CoefficientI','CoefficientQ'})]; %#ok<AGROW>
end
writetable(features,fullfile(out,'pniq_basis.csv'));
fprintf('Model source and descriptor inspection complete: %s\n',out);
end
