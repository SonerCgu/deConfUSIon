function studio=fusiRebaseMovedStudioFiles(studio)
% Update small path fields only; image arrays and save-queue state stay intact.
if ~isstruct(studio)||~isscalar(studio),return;end
studio=fields(studio);
if isfield(studio,'meta')&&isstruct(studio.meta)&&isscalar(studio.meta),studio.meta=fields(studio.meta);end
if isfield(studio,'datasets')&&isstruct(studio.datasets)
    for name=fieldnames(studio.datasets)'
        d=studio.datasets.(name{1});if isstruct(d)&&isscalar(d),studio.datasets.(name{1})=fields(d);end
    end
end
end
function s=fields(s)
for name=fieldnames(s)'
    value=s.(name{1});
    if ischar(value)||(isstring(value)&&isscalar(value)),s.(name{1})=fusiFindMovedDataPath(value);end
end
end
