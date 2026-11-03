%% Configuration of the model
dpd_model.type = 'GMP';
dpd_model.extension_periodica = 0;
dpd_model.pe = 0;
dpd_model.grafica = 0;
dpd_model.h = [];
dpd_model.Ka = [0:2:12];
dpd_model.La = [5*ones(size(dpd_model.Ka))];
dpd_model.Kb = [2:2:6];
dpd_model.Lb = 3*ones(size(dpd_model.Kb));
dpd_model.Mb = 3*ones(size(dpd_model.Kb));
dpd_model.Kc = [2:2:6];
dpd_model.Lc = 3*ones(size(dpd_model.Kc));
dpd_model.Mc = 3*ones(size(dpd_model.Kc));
dpd_model.calculo = 'pinv';
dpd_model.dc = 0;
dpd_model.cs = 0;
dpd_model.pe = 1;
dpd_model.nmax = 200;

warning ('off','stats:robustfit:RankDeficient');
warning ('off','MATLAB:nearlySingularMatrix');
