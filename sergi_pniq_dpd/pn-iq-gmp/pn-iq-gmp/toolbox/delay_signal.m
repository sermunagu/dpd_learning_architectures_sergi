function xd = delay_signal(x, validIdx, delay)
%DELAY_SIGNAL Return x(validIdx-delay) as a column vector.
%
%   xd = DELAY_SIGNAL(x, validIdx, delay) is a small indexing helper used by
%   the multiband GMP generators. validIdx must already be chosen so that
%   validIdx-delay stays inside 1:numel(x).

    if ~isvector(x)
        error('x must be a vector.');
    end
    if ~isvector(validIdx)
        error('validIdx must be a vector.');
    end
    if ~isscalar(delay) || delay ~= round(delay)
        error('delay must be an integer scalar.');
    end

    x = x(:);
    idx = validIdx(:) - delay;

    if any(idx < 1) || any(idx > numel(x))
        error('Requested delay produces indices outside the signal.');
    end

    xd = x(idx);
end
