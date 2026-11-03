function [h, s, nopt, h_full, nAnalyzed, nmse, diagnostics] = omp_domp(X, y, Rmat, mode, Nmax, verbose)
[~,N] = size(X);

if nargin < 5 || isempty(Nmax)
    Nmax = N;
end
if nargin < 6 || isempty(verbose)
    verbose = true;
end

if ~isscalar(Nmax) || Nmax <= 0 || Nmax ~= round(Nmax)
    error('Nmax must be a positive integer scalar.');
end

Nmax = min(Nmax, N);
nAnalyzed = Nmax;

% Normalization of input matrix
for in=1:N
    Xn(:,in)=X(:,in)/norm(X(:,in));
end

Zn = Xn;
h = zeros(N, Nmax);
ve2 = zeros(1, Nmax);
nmse = zeros(1, Nmax);
r = zeros(length(y), Nmax+1);
r(:,1) = y;
s = []; % Support set is empty

diagnostics = struct();
diagnostics.selectedIndex = zeros(Nmax, 1);
diagnostics.selectedName = cell(Nmax, 1);
diagnostics.rawCorrelation = zeros(Nmax, 1);
diagnostics.rawCorrelationAbs = zeros(Nmax, 1);
diagnostics.rawPhaseRad = zeros(Nmax, 1);
diagnostics.rawPhaseDeg = zeros(Nmax, 1);
diagnostics.selectionCorrelation = zeros(Nmax, 1);
diagnostics.selectionCorrelationAbs = zeros(Nmax, 1);
diagnostics.selectionPhaseRad = zeros(Nmax, 1);
diagnostics.selectionPhaseDeg = zeros(Nmax, 1);
diagnostics.coefficient = zeros(Nmax, 1);
diagnostics.coefficientPhaseRad = zeros(Nmax, 1);
diagnostics.coefficientPhaseDeg = zeros(Nmax, 1);

for n = 1:Nmax
    % Sorting correlation
    if strcmp(mode,'OMP')
        Zsel = Xn;
        Cx = abs(Xn'*(r(:,n)));
    else
        Zsel = Zn;
        Cx = abs(Zn'*(r(:,n)));
    end
    
    % We set the correlation of the already selected coefficients to 0,
    % avoiding a new selection.
    Cx(s) = 0;
    [Cxsort ind] = sort(Cx,'descend');
    s(n) = ind(1);

    rawCorr = X(:,s(n))' * r(:,n);
    selectionCorr = Zsel(:,s(n))' * r(:,n);
    
    h(s,n) = normalized_regression(X(:,s), y);

    diagnostics.selectedIndex(n) = s(n);
    diagnostics.selectedName{n} = Rmat{s(n)};
    diagnostics.rawCorrelation(n) = rawCorr;
    diagnostics.rawCorrelationAbs(n) = abs(rawCorr);
    diagnostics.rawPhaseRad(n) = angle(rawCorr);
    diagnostics.rawPhaseDeg(n) = rad2deg(angle(rawCorr));
    diagnostics.selectionCorrelation(n) = selectionCorr;
    diagnostics.selectionCorrelationAbs(n) = abs(selectionCorr);
    diagnostics.selectionPhaseRad(n) = angle(selectionCorr);
    diagnostics.selectionPhaseDeg(n) = rad2deg(angle(selectionCorr));
    diagnostics.coefficient(n) = h(s(n), n);
    diagnostics.coefficientPhaseRad(n) = angle(h(s(n), n));
    diagnostics.coefficientPhaseDeg(n) = rad2deg(angle(h(s(n), n)));
    
    yLS = X(:,s)*h(s,n);
    r(:,n+1) = y-yLS;
    ve2(n) = var(y-yLS);
    
    nmse(n)=20*log10(norm(yLS-y,2)/norm(y,2));
    if verbose
        fprintf('%d/%d - %s - NMSE: %4.2f dB\n', n, Nmax, Rmat{s(n)}, nmse(n));
    end
    
    if (strcmp(mode,'DOMP'))
        % Projection of the selected regressor with the basis set
        C = Zn.'*conj(Zn(:,s(n)));
        % Substraction of the projection
        Zn = Zn - kron(C.',Zn(:,s(n)));
        
        % Rescaling of the new basis
        for in=1:N
            Zn(:,in)=Zn(:,in)/norm(Zn(:,in));
        end
    end
end


% Calculation of the Bayesian Information Criterion (BIC)
M = length(y);
BIC = 2*M*log(ve2)+2*(1:Nmax)*log(2*M); % complex
[~, nopt] = min(BIC);

if verbose
    figure; clf;
    plot(nmse); hold on;
    plot(nopt, nmse(nopt), 'ro');
    title(['Identification NMSE ' mode]);
    xlabel('Number of coefficients');
    ylabel('NMSE (dB)');
end

if verbose
    fprintf('Minimum NMSE: %4.2f dB. BIC NMSE: %4.2f dB. Number of coefficients: %d\n', nmse(end), nmse(nopt), nopt);
end

h_full=h;
diagnostics.nopt_bic = nopt;
diagnostics.nAnalyzed = nAnalyzed;
diagnostics.finalCoefficient = h_full(s(:), nAnalyzed);
diagnostics.finalCoefficientPhaseRad = angle(diagnostics.finalCoefficient);
diagnostics.finalCoefficientPhaseDeg = rad2deg(diagnostics.finalCoefficientPhaseRad);
diagnostics.bicCoefficient = h_full(s(:), nopt);
diagnostics.bicCoefficientPhaseRad = angle(diagnostics.bicCoefficient);
diagnostics.bicCoefficientPhaseDeg = rad2deg(diagnostics.bicCoefficientPhaseRad);
h = h(:,nopt);
end
