function indices = sel_indices(x, y, perc)
%sel_indices Selects a segment of the signal for modeling purposes.
%
%   indices = sel_indices(x, y, perc) returns the index range of a 
%   segment from the output signal y, centered around its maximum 
%   amplitude, for use in modeling (e.g., Volterra-based or DPD modeling).
%
%   INPUTS:
%       x  - Input signal (not used in this function, but included for
%               interface consistency or future extension).
%       y  - Output signal from which the modeling segment is extracted.
%       perc  - Fraction (in [0,1]) indicating the relative length of the 
%               segment to extract (e.g., 0.015 for 1.5% of the signal).
%
%   OUTPUT:
%       indices - Index range [indmodinf : indmodsup] corresponding to the
%                 selected segment of y.

[~, indy] = max(abs(y));
indmodinf = floor(length(y)*perc*floor((indy/length(y))/perc))+1;
indmodsup = ceil(length(y)*perc*ceil((indy/length(y))/perc))-1;

if(indmodsup>length(y))
    indmodsup = length(y);
    indmodinf = length(y)-floor(perc*length(y));
end

indices = indmodinf:indmodsup;
