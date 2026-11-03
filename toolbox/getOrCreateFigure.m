function fh = getOrCreateFigure(figName, doClf)
% getOrCreateFigure Crea o selecciona una figura con nombre específico
%   fh = getOrCreateFigure(figName, doClf)
%   figName : nombre de la figura (string o char)
%   doClf   : booleano, si es true se limpia la figura con clf
%   fh      : handle de la figura

    fh = findobj('Type', 'Figure', 'Name', figName);
    
    if isempty(fh)
        fh = figure('Name', figName);
    else
        figure(fh(1)); % Traer la figura al frente
        hold on
        if doClf
            clf;
        end
    end
end