function selections=scmAutomaticROISelections(fig)
% Older/manual-only viewers may have no audit appdata, hence numeric [].
selections=getappdata(fig,'AutomaticROISelections');
if isempty(selections),selections={};
elseif isstruct(selections),selections=num2cell(selections);
elseif ~iscell(selections),selections={};
end
valid=cellfun(@(c)isstruct(c)&&isscalar(c)&&isfield(c,'roiId')&&isnumeric(c.roiId)&&isscalar(c.roiId),selections);
selections=selections(valid);
end
