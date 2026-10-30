function ordered = deConfUSIon_order_processing_steps(fallback,sources)
% Recover chronological steps from one complete name, never concatenated names.
% Metadata can fill missing tags but must not reorder an explicit chain.
pattern = ['(?:^|(?<=[_\s]))(?:frame[_-]?rej(?:ection)?|scrub|despike|motor|' ...
    'driftcomp(?:ensation)?|pca|ica|(?<!pca_)(?<!pca-)(?:drop)?PC[0-9-]+|' ...
    '(?<!ica_)(?<!ica-)(?:drop)?IC[0-9-]+|' ...
    'imreg(?:demons)?\d*|BPF[^_\s]*|LPF[^_\s]*|' ...
    'HPF[^_\s]*|BSF[^_\s]*|filter|tsmooth|temporalSmooth|subsample|submean|submed|' ...
    'SVD|clutter|chop)(?=[_\s-]|$)'];
best = ''; starts = [];
for k = 1:numel(sources)
    s = char(sources{k});
    positions = regexpi(s,pattern,'start');
    if numel(positions)>numel(starts), best=s; starts=positions; end
end
ordered = {}; classes = {};
for k = 1:numel(starts)
    last = numel(best);
    if k<numel(starts), last=starts(k+1)-1; end
    tag = best(starts(k):last);
    tag = regexprep(tag,'[_\s]+$','');
    tag = regexprep(tag,'_(?:19|20)\d{6}_\d{6}(?:_[0-9a-fA-F]{8})?$','');
    tag = regexprep(tag,'_sl\d+of\d+$','','ignorecase');
    cls = stepClass(tag);
    if any(strcmp(cls,{'pca','ica'}))
        component = 'PC'; if strcmp(cls,'ica'), component='IC'; end
        value = regexpi(tag,['(?:drop)?' component '[0-9-]+|done'],'match','once');
        if startsWith(value,component,'IgnoreCase',true), value=['drop' value]; end
        if ~isempty(value), tag=[cls '_' value]; else, tag=metadataTag(cls,tag); end
    elseif strcmp(cls,'imreg')
        n = regexpi(tag,'(?:n(?:sub)?|imreg(?:demons)?)(\d+)','tokens','once');
        if ~isempty(n)
            method='med'; if contains(lower(tag),'mean'), method='mean'; end
            tag=['imreg_' method '_n' n{1}];
        else, tag=metadataTag(cls,tag);
        end
    elseif any(strcmp(cls,{'despike','driftComp','scrub'})) && ~contains(tag,'_')
        tag=metadataTag(cls,tag);
    end
    tag=regexprep(tag,'[^A-Za-z0-9_\-.]+','_');
    tag=regexprep(tag,'_+','_'); tag=regexprep(tag,'^_+|_+$','');
    ordered{end+1}=tag; classes{end+1}=cls; %#ok<AGROW>
end
for k=1:numel(fallback)
    cls=stepClass(fallback{k});
    if ~any(strcmp(classes,cls))
        ordered{end+1}=fallback{k}; classes{end+1}=cls; %#ok<AGROW>
    end
end

    function tag=metadataTag(cls,tag)
        for j=1:numel(fallback)
            if strcmp(stepClass(fallback{j}),cls), tag=fallback{j}; return; end
        end
    end
end

function cls=stepClass(tag)
token=regexpi(tag,'^[A-Za-z]+','match','once');
cls=lower(token);
if startsWith(cls,'imreg'), cls='imreg';
elseif startsWith(cls,'driftcomp'), cls='driftComp';
elseif startsWith(cls,'frame'), cls='frameRej';
elseif any(strcmp(cls,{'bpf','lpf','hpf','bsf','filter'})), cls='filter';
elseif any(strcmp(cls,{'subsample','submean','submed'})), cls='subsample';
elseif strcmp(cls,'temporalsmooth'), cls='tsmooth';
elseif any(strcmp(cls,{'droppc','pc'})), cls='pca';
elseif any(strcmp(cls,{'dropic','ic'})), cls='ica';
end
end
