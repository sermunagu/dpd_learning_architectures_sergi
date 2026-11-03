function [model] = model_gmp_domp_omp(ymed, xmed, model)

% Substracting DC
xmed = xmed(:)-mean(xmed);
ymed = ymed(:)-mean(ymed);

% Reading model configuration.
Ka = model.Ka; Kb = model.Kb; Kc = model.Kc; La = model.La; Lb = model.Lb; 
Lc = model.Lc; Mb = model.Mb; Mc = model.Mc;
if isfield(model, 'Nmax')
    Nmax = model.Nmax;
else
    Nmax = [];
end
verbose = get_optional_field(model, 'verbose', true);

% Calculation of maximum memory buffers (Qpmax) and (Qnmax)
Qa = max(La); Qb = max(Lb) + max(Mb); Qc = max(Lc) - min(Mc); 
Qpmax = max([Qa, Qb, Qc]); Qnmax = max(Mc);

N = length(ymed);

% Extraction of the signal to model
n = 1:N;
y = ymed(n(1+Qpmax:end-Qnmax));

% Building the measurement matrix
[X_mat, Rmat, orderVec] = buildW(xmed, n, Qpmax, Qnmax, Ka, Kb, Kc, La, Lb, Lc, Mb, Mc);
if isfield(model, 'calculo') && strcmpi(model.calculo, 'matrix_only')
    model.y_aligned = y;
    model.Rmat = Rmat;
    model.orderVec = orderVec;
    if isfield(model, 'returnXmat') && model.returnXmat
        model.X_mat = X_mat;
    end
    return;
end
if ~isempty(model.h)
    ymod = X_mat*model.h;
end

% If model.h is empty, perform the regression
if isempty(model.h)
    switch(model.calculo)
        case 'pinv'
            h_vec = normalized_regression(X_mat, y);
            ymod = X_mat* h_vec;
        case 'OMP'
            [h_vec, s, nopt, h_full, nAnalyzed, nmse_path, selectionDiagnostics] = omp_domp(X_mat, y, Rmat, model.calculo, Nmax, verbose);
            nopt_bic = nopt;
            if isfield(model, 'useLastSparseSolution') && model.useLastSparseSolution
                h_vec = h_full(:, nAnalyzed);
                nopt = nAnalyzed;
            end
            ymod = X_mat* h_vec;
        case 'DOMP'
            [h_vec, s, nopt, h_full, nAnalyzed, nmse_path, selectionDiagnostics] = omp_domp(X_mat, y, Rmat, model.calculo, Nmax, verbose);
            nopt_bic = nopt;
            if isfield(model, 'useLastSparseSolution') && model.useLastSparseSolution
                h_vec = h_full(:, nAnalyzed);
                nopt = nAnalyzed;
            end
            ymod = X_mat* h_vec;      
    end
end

model.nmse = 20*log10(norm(ymod-y)/norm(y));

% Save results in the output structure
if exist('nopt','var')
    model.nopt = nopt;
end
if exist('nopt_bic','var')
    model.nopt_bic = nopt_bic;
end
if exist('s','var')
    model.s = s;
end
if exist('h_vec','var')
    model.h = h_vec;
    model.numcoef = length(h_vec);
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
if exist('y','var')
    model.y_aligned = y;
end
if exist('ymod','var')
    model.ymod = ymod;
end
if exist('Rmat','var')
    model.Rmat = Rmat;
end
if exist('orderVec','var')
    model.orderVec = orderVec;
end
if isfield(model, 'returnXmat') && model.returnXmat
    model.X_mat = X_mat;
end

end

function [Xmat, Rmat, orderVec] = buildW(x, n, Qpmax, Qnmax, Ka, Kb, Kc, La, Lb, Lc, Mb, Mc)
% This function builds the measurement matrix of the GMP model
Regr_a = []; Regr_b = []; Regr_c = [];
Xa = []; Xb = []; Xc = [];
Order_a = []; Order_b = []; Order_c = [];

indk = 0;
for k = 1:length(Ka)
    for l = 0:La(k)
        indk = indk + 1;
        
        Xa(:,indk) = x(n(1+Qpmax-l:end-Qnmax-l)).*(abs(x(n(1+Qpmax-l:end-Qnmax-l))).^(Ka(k)));
        Order_a(indk) = Ka(k) + 1;
        if(Ka(k)~=0)
            Regr_a{indk} = sprintf('x(n-%d)*|x(n-%d)|^{%d}',l,l,Ka(k));
        else
            Regr_a{indk} = sprintf('x(n-%d)',l);
        end
    end
end


indk = 0;
for k = 1:length(Kb)
    for l = 0:Lb(k)
        for m = 1:Mb(k)
            indk = indk + 1;
            Xb(:,indk) = x(n(1+Qpmax-l:end-Qnmax-l)).*(abs(x(n(1+Qpmax-l-m:end-Qnmax-l-m))).^(Kb(k)));
            Order_b(indk) = Kb(k) + 1;
            Regr_b{indk} = sprintf('x(n-%d)|x(n-%d)|^{%d}',l,l+m,Kb(k));
        end
    end
end

indk = 0;
for k = 1:length(Kc)
    for l = 0:Lc(k)
        for m = 1:Mc(k)
            indk = indk + 1;
            Xc(:,indk) = x(n(1+Qpmax-l:end-Qnmax-l)).*(abs(x(n(1+Qpmax-l+m:end-Qnmax-l+m))).^(Kc(k)));
            Order_c(indk) = Kc(k) + 1;
            Regr_c{indk} = sprintf('x(n-%d)|x(n-%d)|^{%d}',l,l-m,Kc(k));
        end
    end
end

Xmat = [Xa,  Xb, Xc];
Rmat = [Regr_a,  Regr_b, Regr_c]';
orderVec = [Order_a, Order_b, Order_c].';
end

function value = get_optional_field(s, name, defaultValue)
if isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
else
    value = defaultValue;
end
end
