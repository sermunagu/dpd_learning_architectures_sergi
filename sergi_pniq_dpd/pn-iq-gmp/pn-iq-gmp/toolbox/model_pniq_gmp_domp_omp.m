function [model] = model_pniq_gmp_domp_omp(ymed, xmed, model)
%MODEL_PNIQ_GMP_DOMP_OMP Phase-normalized IQ GMP with OMP/DOMP selection.
%
% This function follows the same compact interface and configuration style as
% model_gmp_domp_omp. It first builds the conventional complex GMP dictionary,
% then applies the PN-IQ rotation:
%
%   rotation(n) = conj(x(n)) / abs(x(n))
%   y_tilde(n) = rotation(n) * y(n)
%   psi_tilde = rotation .* psi
%
% The PN-IQ dictionary is real-valued:
%
%   Phi = [real(psi_tilde), imag(psi_tilde)]
%
% A selected PN-IQ feature contributes two real coefficients, one for the
% in-phase target and one for the quadrature target.

% Subtracting DC.
xmed = xmed(:) - mean(xmed(:));
ymed = ymed(:) - mean(ymed(:));

% Reading model configuration.
Ka = model.Ka; Kb = model.Kb; Kc = model.Kc; La = model.La; Lb = model.Lb;
Lc = model.Lc; Mb = model.Mb; Mc = model.Mc;
if isfield(model, 'Nmax')
    Nmax = model.Nmax;
else
    Nmax = [];
end
verbose = get_optional_field(model, 'verbose', true);
zeroTol = get_optional_field(model, 'structuralZeroRelativeTolerance', 1e-12);

% Calculation of maximum memory buffers.
Qa = max(La); Qb = max(Lb) + max(Mb); Qc = max(Lc) - min(Mc);
Qpmax = max([Qa, Qb, Qc]);
Qnmax = max(Mc);

N = length(ymed);
n = 1:N;
validIdx = n(1+Qpmax:end-Qnmax);
y = ymed(validIdx);
xAligned = xmed(validIdx);

% Build the complex GMP dictionary, then the PN-IQ real dictionary.
[psi, gmpLabels, gmpOrderVec] = build_gmp_dictionary(xmed, n, Qpmax, Qnmax, ...
    Ka, Kb, Kc, La, Lb, Lc, Mb, Mc);
forcedKeptMask = get_optional_field(model, 'pniqKeptMask', []);
[Phi, yTilde, rotation, featureMap, pniqKeptMask] = build_pniq_dictionary( ...
    psi, xAligned, y, gmpLabels, gmpOrderVec, zeroTol, forcedKeptMask);
featureLabels = {featureMap.label}.';
featureOrderVec = [featureMap.order].';

if isfield(model, 'calculo') && strcmpi(model.calculo, 'matrix_only')
    model.y_aligned = y;
    model.y_tilde = yTilde;
    model.rotation = rotation;
    model.X_mat = Phi;
    model.Phi = Phi;
    model.Psi_gmp = psi;
    model.Rmat = featureLabels;
    model.orderVec = featureOrderVec;
    model.gmpRmat = gmpLabels;
    model.gmpOrderVec = gmpOrderVec;
    model.featureMap = featureMap;
    model.pniqKeptMask = pniqKeptMask;
    return;
end

if isfield(model, 'h') && ~isempty(model.h)
    h_vec = model.h(:);
    if numel(h_vec) ~= size(Phi, 2)
        error('model.h must have one complex coefficient per PN-IQ feature.');
    end
    yTildeMod = Phi * h_vec;
else
    switch upper(model.calculo)
        case 'PINV'
            [cI, cQ] = normalized_real_iq_regression(Phi, yTilde);
            h_vec = cI + 1i*cQ;
            yTildeMod = Phi * h_vec;
        case {'OMP', 'DOMP'}
            [h_vec, s, nopt, h_full, nAnalyzed, nmse_path, selectionDiagnostics] = ...
                pniq_omp_domp(Phi, yTilde, featureLabels, upper(model.calculo), ...
                Nmax, verbose);
            nopt_bic = nopt;
            if isfield(model, 'useLastSparseSolution') && model.useLastSparseSolution
                h_vec = h_full(:, nAnalyzed);
                nopt = nAnalyzed;
            end
            yTildeMod = Phi * h_vec;
        otherwise
            error('Unsupported model.calculo value: %s', model.calculo);
    end
end

ymod = conj(rotation) .* yTildeMod;
model.nmse = 20*log10(norm(ymod - y) / norm(y));

% Save results in the output structure.
if exist('nopt','var')
    model.nopt = nopt;
end
if exist('nopt_bic','var')
    model.nopt_bic = nopt_bic;
end
if exist('s','var')
    model.s = s;
    model.selectedFeatureMap = featureMap(s);
end
if exist('h_vec','var')
    model.h = h_vec;
    model.cI = real(h_vec);
    model.cQ = imag(h_vec);
    model.numcoef = length(h_vec);
    model.realParameterCount = 2 * nnz(abs(h_vec) > 0);
end
if exist('h_full','var')
    model.h_full = h_full;
end
if exist('nAnalyzed','var')
    model.nAnalyzed = nAnalyzed;
end
if exist('nmse_path','var')
    model.nmse_path = nmse_path;
end
if exist('selectionDiagnostics','var')
    model.selectionDiagnostics = selectionDiagnostics;
end

model.y_aligned = y;
model.y_tilde = yTilde;
model.rotation = rotation;
model.ymod = ymod;
model.y_tilde_mod = yTildeMod;
model.Rmat = featureLabels;
model.orderVec = featureOrderVec;
model.gmpRmat = gmpLabels;
model.gmpOrderVec = gmpOrderVec;
model.featureMap = featureMap;
model.pniqKeptMask = pniqKeptMask;
if isfield(model, 'returnXmat') && model.returnXmat
    model.X_mat = Phi;
    model.Phi = Phi;
    model.Psi_gmp = psi;
end

end

function [Xmat, Rmat, orderVec] = build_gmp_dictionary(x, n, Qpmax, Qnmax, ...
    Ka, Kb, Kc, La, Lb, Lc, Mb, Mc)
% Build the same conventional GMP dictionary used by model_gmp_domp_omp.
Regr_a = {}; Regr_b = {}; Regr_c = {};
Xa = []; Xb = []; Xc = [];
Order_a = []; Order_b = []; Order_c = [];

indk = 0;
for k = 1:length(Ka)
    for l = 0:La(k)
        indk = indk + 1;
        idx = n(1+Qpmax-l:end-Qnmax-l);
        Xa(:,indk) = x(idx) .* (abs(x(idx)).^(Ka(k)));
        Order_a(indk) = Ka(k) + 1;
        if Ka(k) ~= 0
            Regr_a{indk} = sprintf('x(n-%d)*|x(n-%d)|^{%d}', l, l, Ka(k));
        else
            Regr_a{indk} = sprintf('x(n-%d)', l);
        end
    end
end

indk = 0;
for k = 1:length(Kb)
    for l = 0:Lb(k)
        for m = 1:Mb(k)
            indk = indk + 1;
            idxCarrier = n(1+Qpmax-l:end-Qnmax-l);
            idxEnvelope = n(1+Qpmax-l-m:end-Qnmax-l-m);
            Xb(:,indk) = x(idxCarrier) .* (abs(x(idxEnvelope)).^(Kb(k)));
            Order_b(indk) = Kb(k) + 1;
            Regr_b{indk} = sprintf('x(n-%d)|x(n-%d)|^{%d}', l, l+m, Kb(k));
        end
    end
end

indk = 0;
for k = 1:length(Kc)
    for l = 0:Lc(k)
        for m = 1:Mc(k)
            indk = indk + 1;
            idxCarrier = n(1+Qpmax-l:end-Qnmax-l);
            idxEnvelope = n(1+Qpmax-l+m:end-Qnmax-l+m);
            Xc(:,indk) = x(idxCarrier) .* (abs(x(idxEnvelope)).^(Kc(k)));
            Order_c(indk) = Kc(k) + 1;
            Regr_c{indk} = sprintf('x(n-%d)|x(n-%d)|^{%d}', l, l-m, Kc(k));
        end
    end
end

Xmat = [Xa, Xb, Xc];
Rmat = [Regr_a, Regr_b, Regr_c].';
orderVec = [Order_a, Order_b, Order_c].';
end

function [Phi, yTilde, rotation, featureMap, kept] = build_pniq_dictionary( ...
    psi, xRows, yRows, gmpLabels, gmpOrderVec, zeroTol, forcedKeptMask)
% Build real PN-IQ features from the complex GMP dictionary.
xRows = xRows(:);
yRows = yRows(:);

rotation = complex(ones(size(xRows)));
nonzero = abs(xRows) > eps(class(abs(xRows)));
rotation(nonzero) = conj(xRows(nonzero)) ./ abs(xRows(nonzero));

psiTilde = rotation .* psi;
yTilde = rotation .* yRows;

PhiFull = [real(psiTilde), imag(psiTilde)];
nRegs = numel(gmpLabels);
featureMapFull(1, 2*nRegs) = struct( ...
    'sourceRegressorIndex', 0, ...
    'isQ', false, ...
    'label', '', ...
    'sourceLabel', '', ...
    'order', 0);

for k = 1:nRegs
    featureMapFull(k) = struct( ...
        'sourceRegressorIndex', k, ...
        'isQ', false, ...
        'label', sprintf('real(PN{%s})', gmpLabels{k}), ...
        'sourceLabel', gmpLabels{k}, ...
        'order', gmpOrderVec(k));
    featureMapFull(nRegs+k) = struct( ...
        'sourceRegressorIndex', k, ...
        'isQ', true, ...
        'label', sprintf('imag(PN{%s})', gmpLabels{k}), ...
        'sourceLabel', gmpLabels{k}, ...
        'order', gmpOrderVec(k));
end

norms = sqrt(sum(PhiFull.^2, 1));
threshold = zeroTol * max(1, max(norms));
if nargin >= 7 && ~isempty(forcedKeptMask)
    kept = logical(forcedKeptMask(:)).';
    if numel(kept) ~= size(PhiFull, 2)
        error('Provided model.pniqKeptMask has %d entries, but the full PN-IQ dictionary has %d columns.', ...
            numel(kept), size(PhiFull, 2));
    end
else
    kept = norms > threshold;
end
Phi = PhiFull(:, kept);
featureMap = featureMapFull(kept);
end

function [h, s, nopt, h_full, nAnalyzed, nmse, diagnostics] = ...
    pniq_omp_domp(Phi, yTilde, Rmat, mode, Nmax, verbose)
% OMP/DOMP for real PN-IQ features and complex phase-normalized target.
[~, N] = size(Phi);

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

normPhi = sqrt(sum(Phi.^2, 1));
normPhi(normPhi <= eps) = 1;
Phin = Phi ./ normPhi;

Zn = Phin;
h_full = complex(zeros(N, Nmax));
ve2 = zeros(1, Nmax);
nmse = zeros(1, Nmax);
r = complex(zeros(length(yTilde), Nmax+1));
r(:,1) = yTilde;
s = [];

diagnostics = struct();
diagnostics.selectedIndex = zeros(Nmax, 1);
diagnostics.selectedName = cell(Nmax, 1);
diagnostics.selectionScore = zeros(Nmax, 1);
diagnostics.coefficientI = zeros(Nmax, 1);
diagnostics.coefficientQ = zeros(Nmax, 1);

for iter = 1:Nmax
    if strcmp(mode, 'OMP')
        Zsel = Phin;
    else
        Zsel = Zn;
    end

    corrI = Zsel' * real(r(:,iter));
    corrQ = Zsel' * imag(r(:,iter));
    score = sqrt(abs(corrI).^2 + abs(corrQ).^2);
    score(s) = 0;
    [~, best] = max(score);
    s(iter) = best;

    active = s(:);
    [cI, cQ] = normalized_real_iq_regression(Phi(:, active), yTilde);
    hActive = cI + 1i*cQ;
    h_full(active, iter) = hActive;

    yLS = Phi(:, active) * hActive;
    r(:,iter+1) = yTilde - yLS;
    ve2(iter) = var(yTilde - yLS);
    nmse(iter) = 20*log10(norm(yLS - yTilde, 2) / norm(yTilde, 2));

    diagnostics.selectedIndex(iter) = best;
    diagnostics.selectedName{iter} = Rmat{best};
    diagnostics.selectionScore(iter) = score(best);
    diagnostics.coefficientI(iter) = cI(end);
    diagnostics.coefficientQ(iter) = cQ(end);

    if verbose
        fprintf('%d/%d - %s - PN-IQ NMSE: %4.2f dB\n', ...
            iter, Nmax, Rmat{best}, nmse(iter));
    end

    if strcmp(mode, 'DOMP')
        q = Zn(:, best);
        qNorm = norm(q);
        if qNorm > eps
            q = q / qNorm;
            Zn = Zn - q * (q' * Zn);
            znNorm = sqrt(sum(Zn.^2, 1));
            valid = znNorm > eps;
            Zn(:, valid) = Zn(:, valid) ./ znNorm(valid);
            Zn(:, ~valid) = 0;
        end
        Zn(:, best) = 0;
    end
end

M = length(yTilde);
BIC = 2*M*log(ve2) + 2*(1:Nmax)*log(2*M);
[~, nopt] = min(BIC);

if verbose
    figure; clf;
    plot(nmse); hold on;
    plot(nopt, nmse(nopt), 'ro');
    title(['Identification NMSE PN-IQ ' mode]);
    xlabel('Number of selected PN-IQ features');
    ylabel('NMSE (dB)');
    fprintf('Minimum NMSE: %4.2f dB. BIC NMSE: %4.2f dB. Number of features: %d\n', ...
        nmse(end), nmse(nopt), nopt);
end

h = h_full(:, nopt);
diagnostics.nopt_bic = nopt;
diagnostics.nAnalyzed = nAnalyzed;
diagnostics.finalCoefficient = h_full(s(:), nAnalyzed);
diagnostics.bicCoefficient = h_full(s(:), nopt);
end

function [cI, cQ] = normalized_real_iq_regression(Phi, yTilde)
% Least-squares fit after column normalization, solved independently for I/Q.
if isempty(Phi)
    cI = zeros(0, 1);
    cQ = zeros(0, 1);
    return;
end

normPhi = sqrt(sum(Phi.^2, 1)).';
bad = ~isfinite(normPhi) | normPhi <= eps;
normPhi(bad) = 1;
PhiN = Phi ./ normPhi.';

cIN = pinv(PhiN) * real(yTilde);
cQN = pinv(PhiN) * imag(yTilde);

cI = cIN ./ normPhi;
cQ = cQN ./ normPhi;
end

function value = get_optional_field(s, name, defaultValue)
if isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
else
    value = defaultValue;
end
end
