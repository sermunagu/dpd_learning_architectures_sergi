function [U, y, Rmat] = model_gmp_generate_X(y, u, model, nsel)
%MODEL_GMP_GENERATE_X  Regression (measurement) matrix of a behavioral model.
%
%   [U, y, Rmat] = model_gmp_generate_X(y, u, model)
%   [U, y, Rmat] = model_gmp_generate_X(y, u, model, nsel)
%
%   Builds the regression matrix U so that the target is modelled as
%   y ~ U*w. Each column of U is one basis function (regressor) built from
%   the input u.
%
% Inputs:
%   y     : target signal (model output). It is not used to build U, it is
%           only returned aligned with the rows of U.
%   u     : input signal used to build the regressors.
%   model : model structure (see confset/model_configuration_B.m):
%           type : 'GMP' (built here), 'FV' or 'CVS' (external builders)
%           pe   : 1 = periodic extension, U has as many rows as samples
%                  0 = no extension, the first Qp samples are discarded
%           GMP orders (K) and memory depths (L, M):
%           Ka, La     : aligned terms           u(n-l)|u(n-l)|^k
%           Kb, Lb, Mb : lagging envelope terms  u(n-l)|u(n-l-m)|^k
%           Kc, Lc, Mc : leading envelope terms  u(n-l-m)|u(n-l)|^k
%           FV / CVS   : P, Q
%   nsel  : (optional) subset of contiguous sample indices to use.
%
% Outputs:
%   U    : regression matrix [Nr x R], one column per regressor
%          (Nr = number of samples with pe = 1, minus Qp with pe = 0).
%   y    : target signal aligned with the rows of U (DC removed).
%   Rmat : R x 1 cell array with the text description of each regressor
%          (written in terms of x instead of u).
%
% Notes:
%   - The DC component of u and y is removed before building U.
%   - For every Ka(k) == 0 the conjugate term conj(u(n-l)) is always added
%     right after u(n-l). model.cs is ignored here, unlike in
%     capsule_v3_DPD/model_gmp_generate_X_v2.m.
%   - 'FV' and 'CVS' require fv, cvs, buildWfv and buildWcvs, which are not
%     part of this repository.

% Remove DC and work with column vectors
u = u(:) - mean(u);
y = y(:) - mean(y);
if nargin == 4
    u = u(nsel);
    y = y(nsel);
end

% Maximum memory depth: past (Qp) and future (Qn) samples
switch model.type
    case 'GMP'
        Ka = model.Ka; Kb = model.Kb; Kc = model.Kc;
        La = model.La; Lb = model.Lb; Lc = model.Lc;
        Mb = model.Mb; Mc = model.Mc;
        Qp = max([max(La), max(Lb) + max(Mb), max(Lc) + max(Mc)]);
        Qn = 0;
    case {'FV', 'CVS'}
        Qp = 0;
        Qn = model.Q;
    otherwise
        error('model_gmp_generate_X:unknownType', ...
            'Unknown model type ''%s''.', model.type);
end

% Sample indices. With periodic extension the signal wraps around, so the
% memory of the first samples is taken from the end of the signal.
N = length(y);
if model.pe
    idx = [N-Qp+1:N, 1:N, 1:Qn];
else
    idx = 1:N;
end
y = y(idx(1+Qp:end-Qn));

% Building the measurement matrix
switch model.type
    case 'GMP'
        [U, Rmat] = buildWgmp(u, idx, Qp, Qn, Ka, Kb, Kc, La, Lb, Lc, Mb, Mc);
    case 'FV'
        md_reg = fv(model.P, model.Q);
        [U, Rmat] = buildWfv(u, md_reg.q, md_reg.c);
    case 'CVS'
        md_reg = cvs(model.P, model.Q);
        [U, Rmat] = buildWcvs(u, md_reg.q, md_reg.c);
end

end

function [U, Rmat] = buildWgmp(x, idx, Qp, Qn, Ka, Kb, Kc, La, Lb, Lc, Mb, Mc)
% Builds the measurement matrix of the GMP model

% Delayed copies of the input: D(:,q+1) = x(n-q), q = 0..Qp
Nr = length(idx) - Qp - Qn;
D = zeros(Nr, Qp+1, 'like', x);
for q = 0:Qp
    D(:,q+1) = x(idx(1+Qp-q:end-Qn-q));
end
absD = abs(D);

% Number of regressors of each family, to preallocate U and Rmat
nA = sum(La+1) + sum(La(Ka == 0)+1);
nB = sum((Lb+1).*Mb);
nC = sum((Lc+1).*Mc);
U = zeros(Nr, nA+nB+nC, 'like', x);
Rmat = cell(nA+nB+nC, 1);
r = 0;

% Aligned terms: x(n-l)|x(n-l)|^k, plus conj(x(n-l)) when k = 0
for k = 1:length(Ka)
    for l = 0:La(k)
        r = r + 1;
        U(:,r) = D(:,l+1).*(absD(:,l+1).^Ka(k));
        if Ka(k) ~= 0
            Rmat{r} = sprintf('x(n%+1.0f)|x(n%+1.0f)|^{%d}', -l, -l, Ka(k));
        else
            Rmat{r} = sprintf('x(n%+1.0f)', -l);
            r = r + 1;
            U(:,r) = conj(D(:,l+1));
            Rmat{r} = sprintf('x*(n%+1.0f)', -l);
        end
    end
end

% Lagging envelope terms: x(n-l)|x(n-l-m)|^k
for k = 1:length(Kb)
    for l = 0:Lb(k)
        for m = 1:Mb(k)
            r = r + 1;
            U(:,r) = D(:,l+1).*(absD(:,l+m+1).^Kb(k));
            Rmat{r} = sprintf('x(n%+1.0f)|x(n%+1.0f)|^{%d}', -l, -l-m, Kb(k));
        end
    end
end

% Leading envelope terms: x(n-l-m)|x(n-l)|^k
for k = 1:length(Kc)
    for l = 0:Lc(k)
        for m = 1:Mc(k)
            r = r + 1;
            U(:,r) = D(:,l+m+1).*(absD(:,l+1).^Kc(k));
            Rmat{r} = sprintf('x(n%+1.0f)|x(n%+1.0f)|^{%d}', -l-m, -l, Kc(k));
        end
    end
end

end
