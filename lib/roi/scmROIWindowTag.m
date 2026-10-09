function tag=scmROIWindowTag(signalSec,selection)
% Filename provenance in minutes. Do not infer a search from a manual ROI.
if nargin<2, selection=[]; end
fmt=@(v)strrep(sprintf('%.6g',v/60),'.','p');
span=@(w)[fmt(w(1)) 'to' fmt(w(2)) 'min'];
assert(numel(signalSec)==2&&all(isfinite(signalSec)), ...
    'deConfUSIon:ROIWindow','Signal window must have two finite endpoints.');
if isstruct(selection)&&isfield(selection,'searchIntervalSec')&&isfield(selection,'plateauSec')
    tag=['search' span(selection.searchIntervalSec)];
    if selection.plateauSec>0
        tag=[tag '_over' fmt(selection.plateauSec) 'minplateau'];
    else
        tag=[tag '_wholeSearchMean'];
    end
    tag=[tag '_selected' span(selection.signalSec)];
else
    tag=['fixed' span(signalSec)];
end
end
