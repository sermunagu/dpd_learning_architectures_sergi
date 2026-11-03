function [dpd, selectedIndices, tag] = select_dpd_indices(dpd, indices)
% SELECT_DPD_INDICES Select original signal indices in the requested order.
% Inputs: loaded DPD struct and nonempty numeric vector of unique indices.
% Outputs: selected struct, original indices as a row, and a filename tag.
    validateattributes(indices, {'numeric'}, ...
        {'vector','nonempty','real','finite','integer','positive','<=',numel(dpd)}, ...
        mfilename,'dpd_indices');
    selectedIndices = double(indices(:).');
    assert(numel(unique(selectedIndices)) == numel(selectedIndices), ...
        'DPD:DuplicateIndices','dpd_indices must contain unique indices.');
    dpd = dpd(selectedIndices);
    % Compact consecutive ascending runs without changing measurement order.
    starts = [1 find(diff(selectedIndices) ~= 1)+1];
    stops = [starts(2:end)-1 numel(selectedIndices)];
    parts = strings(size(starts));
    for k = 1:numel(starts)
        first = selectedIndices(starts(k));
        last = selectedIndices(stops(k));
        if first == last, parts(k) = string(first);
        else, parts(k) = sprintf('%d-%d',first,last); end
    end
    tag = char(strjoin(parts,'_'));
    if numel(tag) > 64
        digest = java.security.MessageDigest.getInstance('SHA-256');
        digest.update(uint8(sprintf('%.0f,',selectedIndices)));
        tag = ['sha256_' lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]))];
    end
end
