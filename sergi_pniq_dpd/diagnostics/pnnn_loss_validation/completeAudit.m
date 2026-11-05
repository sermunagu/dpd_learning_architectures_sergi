function completeAudit()
% COMPLETEAUDIT Classify all saved MAT schemas and compare capture metadata.
% No inputs; outputs are new logs/CSV here. No training or model fitting.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here)); repo=fileparts(root);
assert(~isfile(fullfile(here,'schema_inventory.csv')),'Audit already complete.');
diary(fullfile(here,'completion.log')); c=onCleanup(@() diary('off'));
files=readlines(fullfile(here,'mat_files.txt')); files=files(strlength(files)>0); schema=table();
for k=1:numel(files)
    p=fullfile(repo,files(k)); w=whos('-file',p); names=string({w.name});
    schema=[schema;table(files(k),strjoin(names,';'),all(ismember(["x","y"],names)), ...
        'VariableNames',{'File','TopLevelVariables','HasXY'})]; %#ok<AGROW>
end
writetable(schema,fullfile(here,'schema_inventory.csv'));
disp(schema(schema.HasXY,{'File'}));
a=load(fullfile(root,'measurements','experiment20260429T134032_xy.mat'));
o=load(fullfile(repo,'results','experimentosSergi20261023','experiment20261023T102742_xy.mat'));
f=load(fullfile(root,'measurements','experiment20260429T134032_forward_xy.mat'));
oc=load(fullfile(repo,'results','experiment20261023T102742_xy.mat'));
fprintf('October copies exact x/y: %d/%d\n',isequal(o.x,oc.x),isequal(o.y,oc.y));
fprintf('April/October input exact: %d; relative L2 %.15g\n',isequal(a.x,o.x),norm(a.x(:)-o.x(:))/norm(o.x(:)));
fprintf('April/October target relative L2 %.15g; RMS ratio %.15g\n',norm(a.y(:)-o.y(:))/norm(o.y(:)),norm(a.y(:))/norm(o.y(:)));
fprintf('April ILC vs forward input exact %d; fs %.0f; October fs %.0f\n',isequal(a.x,f.x),a.fs,o.fs);
fprintf('April exp_config available %d; October exp_config available %d\n',isfield(a,'exp_config'),isfield(o,'exp_config'));
fprintf('April info_signal fields: %s\n',strjoin(fieldnames(a.info_signal),', '));
fprintf('All %d original MAT schemas inspected.\n',height(schema));
ff=dir(fullfile(here,'*.m')); for k=1:numel(ff), fprintf('CHECKCODE %s\n',ff(k).name); disp(checkcode(fullfile(here,ff(k).name),'-id')); end
end
