function deConfUSIon_popup_autofit_apply(hFig)
% Direct wrapper for HUMoR popup auto-fit.
if nargin < 1 || isempty(hFig) || ~ishghandle(hFig)
    try, hFig = gcf; catch, return; end
end
try
    deConfUSIon_ui('present',hFig);
catch
end
end
