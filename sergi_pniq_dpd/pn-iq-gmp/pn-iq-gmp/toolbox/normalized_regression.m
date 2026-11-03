function h = normalized_regression(X, y)
%NORMALIZED_REGRESSION Least-squares fit after column normalization.

    if isempty(X)
        h = zeros(0, 1);
        return;
    end

    normX = vecnorm(X);
    bad = ~isfinite(normX) | normX <= eps;
    normX(bad) = 1;

    Xn = X * diag(1./normX);

    h_n = pinv(Xn) * y;
    h = diag(1./normX) * h_n;
end
