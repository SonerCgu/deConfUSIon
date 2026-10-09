function G = deConfUSIon_region_groups(infoRegions, mode)
% deConfUSIon_region_groups  Stable coarse atlas grouping for ROI summaries.
% The voxel atlas is unchanged; this returns a map that callers can use to
% aggregate detailed labels into broad anatomical families.
if nargin < 2 || isempty(mode), mode='coarse'; end
names = localNames(infoRegions);
G = struct('mode',char(mode),'names',{{}},'map',zeros(numel(names),1), ...
    'sourceNames',{names});
if isempty(names), return; end
families = {'Cortex','Hippocampus','Striatum','Thalamus','Hypothalamus', ...
    'Midbrain','Brainstem','Cerebellum','White matter','Ventricle','Other'};
G.names = families;
for k=1:numel(names)
    s=lower(names{k});
    if contains(s,'hipp') || contains(s,'subiculum') || ~isempty(regexp(s,'^ca[123]$','once')), j=2;
    elseif contains(s,'striat') || contains(s,'caud') || contains(s,'putamen'), j=3;
    elseif contains(s,'thalam'), j=4;
    elseif contains(s,'hypothal'), j=5;
    elseif contains(s,'midbrain') || contains(s,'superior collic') || contains(s,'inferior collic'), j=6;
    elseif contains(s,'pons') || contains(s,'medulla') || contains(s,'brainstem'), j=7;
    elseif contains(s,'cerebell'), j=8;
    elseif contains(s,'white matter') || contains(s,'fiber') || contains(s,'corpus callos'), j=9;
    elseif contains(s,'ventricle') || contains(s,'aqueduct'), j=10;
    elseif contains(s,'cort') || contains(s,'olfact') || contains(s,'isocortex') || ...
            ~isempty(regexp(s,'^(mop|mos|ssp|sss|ss|vis|aud|ac[ad v]?|pl|ila|orb|rspo)','once')), j=1;
    else, j=11;
    end
    G.map(k)=j;
end
end

function names=localNames(R)
names={};
if ~isstruct(R), return; end
for key={'name','names','acr','acronym','label','labels'}
    if isfield(R,key{1})
        v=R.(key{1});
        if ischar(v), names=cellstr(v);
        elseif isstring(v), names=cellstr(v(:));
        elseif iscell(v), names=cellfun(@(x)char(string(x)),v(:),'UniformOutput',false);
        end
        if ~isempty(names), return; end
    end
end
end
