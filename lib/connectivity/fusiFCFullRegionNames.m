function out=fusiFCFullRegionNames(names,T)
% Anatomical names for selectors; retain hemisphere identity without truncation.
if nargin<2,T=struct();end
if ischar(names),names=cellstr(names);elseif isstring(names),names=cellstr(names);end
out=names;
for k=1:numel(names)
    name=regexprep(strtrim(char(names{k})),'\s*\[[^\]]*\]\s*$','');side='';base=name;
    sliceSuffix=regexp(base,'\s*\(slice \d+\)$','match','once');
    base=regexprep(base,'\s*\(slice \d+\)$','');name=base;
    token=regexp(name,'^(L|R|Left|Right)[ _]+(.+)$','tokens','once','ignorecase');
    if ~isempty(token),side='Left';if any(strcmpi(token{1},{'R','Right'})),side='Right';end;base=token{2};end
    if contains(base,'|'),parts=strsplit(base,'|');base=strtrim(parts{end});
    elseif isstruct(T)&&isfield(T,'names')&&isfield(T,'fullNames')
        n=min(numel(T.names),numel(T.fullNames));hit=find(strcmpi(name,T.names(1:n)),1);
        if isempty(hit)
            keys=regexprep(T.names(1:n),'^(L|R|Left|Right)[ _]+','','ignorecase');hit=find(strcmpi(base,keys),1);
        end
        if ~isempty(hit),base=char(T.fullNames{hit});end
    end
    base=regexprep(base,'^(Left|Right)[ _]+','','ignorecase');
    if ~isempty(side),base=[side ' ' base];end
    out{k}=[base sliceSuffix];
end
end
