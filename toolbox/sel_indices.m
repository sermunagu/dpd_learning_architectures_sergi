function indices = sel_indices(~, ydpd, perc)
% SEL_INDICES  Selects a contiguous window of samples around the peak of |ydpd|.
%
%   indices = sel_indices(xdpd, ydpd, perc)
%
% Inputs:
%   xdpd : not used (kept for interface compatibility)
%   ydpd : signal whose peak |ydpd| selects the window
%   perc : fraction of the record in the window, 0 < perc <= 1 (e.g. 0.1)
%
% Output:
%   indices : floor(perc*length(ydpd)) contiguous sample indices
%
% The record is divided into consecutive windows of floor(perc*N) samples
% and the window that contains the maximum of |ydpd| is returned. If that
% window is cut by the end of the record, it is shifted back so that it
% always has the full length.

N = length(ydpd);
L = floor(perc*N);                      % Window length
if L < 1 || perc > 1
    error('sel_indices:InvalidPerc', ...
        'perc must give at least one sample and be <= 1 (perc = %g, N = %d).', perc, N);
end

[~, ipk] = max(abs(ydpd));
k = ceil(ipk/L);                        % Window that contains the peak
first = (k-1)*L + 1;
last  = min(k*L, N);
first = min(first, last - L + 1);       % Full length at the end of the record

indices = first:last;
end
