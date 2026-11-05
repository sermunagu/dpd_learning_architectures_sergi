function auditInventory()
% AUDITINVENTORY Inspect capture metadata and source provenance; no inference.
% No inputs; writes a new inventory log/CSV inside this diagnostic directory.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here)); repo=fileparts(root);
assert(~isfile(fullfile(here,'inventory.csv')),'Inventory already exists.');
out=tempname(here); mkdir(out);
diary(fullfile(out,'inventory.log')); cleanup=onCleanup(@() diary('off'));
files=dir(fullfile(repo,'**','*.mat')); inventory=table();
for k=1:numel(files)
    p=fullfile(files(k).folder,files(k).name);
    if contains(p,[filesep '.git' filesep]), continue; end
    if endsWith(files(k).name,'_xy.mat') || strcmp(files(k).name,'experiment.mat') || ...
            ~isempty(regexp(files(k).name,'^experiment\d{8}T\d{6}\.mat$','once'))
        w=whos('-file',p); fprintf('\nFILE %s\n',p); disp({w.name});
        vars=intersect({w.name},{'fs','description','exp_config','provenance','cfg','split','info_signal','filenamedate'});
        d=load(p,vars{:});
        if isfield(d,'description'), disp(d.description); end
        if isfield(d,'fs'), disp(d.fs); end
        if isfield(d,'exp_config'), disp(d.exp_config); end
        if isfield(d,'provenance'), disp(d.provenance); end
        if isfield(d,'info_signal'), disp(d.info_signal); end
        if isfield(d,'cfg'), disp(d.cfg); end
        if isfield(d,'split'), disp(d.split); end
        hasXY=all(ismember({'x','y'},{w.name}));
        n=NaN; rmsX=NaN; rmsY=NaN;
        if hasXY
            xy=load(p,'x','y'); n=numel(xy.x); rmsX=sqrt(mean(abs(xy.x(:)).^2)); rmsY=sqrt(mean(abs(xy.y(:)).^2));
            fprintf('XY length %d/%d; RMS %.12g/%.12g\n',n,numel(xy.y),rmsX,rmsY);
        end
        source=""; if isfield(d,'provenance') && isfield(d.provenance,'sourceFile'), source=string(d.provenance.sourceFile); end
        inventory=[inventory;table(string(p),hasXY,n,rmsX,rmsY,source, ...
            'VariableNames',{'Path','HasXY','Samples','RMSX','RMSY','SourceFile'})]; %#ok<AGROW>
    end
end
writetable(inventory,fullfile(here,'inventory.csv'));
fprintf('INVENTORY COMPLETE: %d candidate/source files.\n',height(inventory));
end
