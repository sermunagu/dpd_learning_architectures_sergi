function verifyHiddenBits(out)
% VERIFYHIDDENBITS Compare saved output IEEE-754 bit patterns, including zeros.
% Input: completed run folder. Output: one JSON record; no inference or update.
    file=fullfile(out,'output_bit_verification.json');
    assert(~isfile(file)); beforeRng=rng;
    F=load(fullfile(out,'final_model.mat'));
    B=load(F.provenance.source.model);
    rows=struct('Epoch',{},'OutputWeightsBitsExact',{},'OutputBiasBitsExact',{});
    for epoch=[41 82 123 164]
        if epoch==164
            network=F.model.network;
        else
            C=load(fullfile(out,sprintf('checkpoint_epoch%04d.mat',epoch)),'network');
            network=C.network;
        end
        exact=false(1,2);
        for k=3:4
            a=extractdata(B.model.network.Learnables.Value{k});
            b=extractdata(network.Learnables.Value{k});
            assert(isa(a,'single') && isa(b,'single') && isequal(size(a),size(b)));
            exact(k-2)=isequal(typecast(a(:),'uint32'),typecast(b(:),'uint32'));
        end
        assert(all(exact),'Saved output bit patterns changed.');
        rows(end+1)=struct('Epoch',epoch,'OutputWeightsBitsExact',exact(1), ...
            'OutputBiasBitsExact',exact(2)); %#ok<AGROW>
    end
    assert(isequal(beforeRng,rng));
    fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); closeFile=onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(rows,PrettyPrint=true));
    disp(struct2table(rows));
    assert(isempty(checkcode(mfilename('fullpath'),'-id')));
end
