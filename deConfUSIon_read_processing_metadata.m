function d = deConfUSIon_read_processing_metadata(file)
% Read only small provenance fields from a v7.3 result, never its image array.
% Legacy files can have stale top-level labels that disagree with newData.
d=struct();
try
    root=h5info(file,'/newData');
catch
    return; % Older MAT formats keep the existing top-level naming fallback.
end
names={'HUMOR_fullDisplayName','displayNameFull','preprocDisplayName', ...
    'preprocessing','sourceFileName','datasetSortTime'};
d=readFields(file,root,names);
spec={ ...
    'driftStats',{'method','applied','polyOrder','baselineSec','injectionSec','responseSec','tailSec','nComp','restoreMode'}; ...
    'pcaStats',{'applied','selectedComponents'}; ...
    'icaStats',{'applied','selectedComponents'}};
for k=1:size(spec,1)
    path=['/newData/' spec{k,1}];
    try
        st=readFields(file,h5info(file,path),spec{k,2});
        if ~isempty(fieldnames(st)), d.(spec{k,1})=st; end
    catch
    end
end
end

function d=readFields(file,group,names)
d=struct();
for k=1:numel(group.Datasets)
    info=group.Datasets(k); name=info.Name;
    if ~ismember(name,names) || prod(info.Dataspace.Size)>4096, continue; end
    path=[group.Name '/' name];
    try
        emptyAttribute=strcmp({info.Attributes.Name},'MATLAB_empty');
        if any(emptyAttribute) && any(info.Attributes(find(emptyAttribute,1)).Value), continue; end
        value=h5read(file,path);
        kind=h5readatt(file,path,'MATLAB_class');
        if strcmp(kind,'char'), value=char(value(:)');
        elseif strcmp(kind,'logical'), value=logical(value);
        elseif ~isnumeric(value), continue;
        end
        d.(name)=value;
    catch
        % References and large diagnostic arrays are intentionally skipped.
    end
end
end
