function id=fusiLightSuiteIdentity(context)
% Read window provenance from metadata/paths without loading recording arrays.
if nargin<1||~isstruct(context),context=struct();end
sources={context};
for field={'config','opts','inputMetadata','meta'}
    if isfield(context,field{1})&&isstruct(context.(field{1})),sources{end+1}=context.(field{1});end %#ok<AGROW>
end
animal=findValue(sources,{'animalid','mouseid','subjectid','animal','mouse','subject'});
scan=findValue(sources,{'scanid','scannumber','scan'});
source=findValue(sources,{'sourcefile','loadedfile','lazyfile'});
project=findValue(sources,{'savepath','outputfolder'});
[~,recording,ext]=fileparts(strrep(source,'\',filesep));
if strcmpi(ext,'.gz'),[~,recording]=fileparts(recording);end
if isempty(recording),recording=findValue(sources,{'mousename','name'});end
token=regexpi(recording,'^(.*?)_?(scan\d+(?:_ES)?)(?:_|$)','tokens','once');
if ~isempty(token)
    if isempty(animal),animal=regexprep(token{1},'[_ -]+$','');end
    if isempty(scan),scan=token{2};end
end
if isempty(animal),animal=recording;end
if isempty(animal),animal='not specified';end
if isempty(scan),scan='not specified';end
id=struct('animal',animal,'scan',scan,'recording',recording,'sourceFile',source,'projectFolder',project, ...
    'label',sprintf('Animal: %s  |  Scan: %s',animal,scan));
end

function value=findValue(sources,names)
value='';
for k=1:numel(sources)
    fields=fieldnames(sources{k});keys=lower(string(strrep(fields,'_','')));
    for name=names
        index=find(strcmp(keys,name{1}),1);if isempty(index),continue;end
        v=sources{k}.(fields{index});
        if (ischar(v)&&isrow(v))||(isstring(v)&&isscalar(v)),value=strtrim(char(v));
        elseif isnumeric(v)&&isscalar(v)&&isfinite(v),value=num2str(v);end
        if ~isempty(value),return;end
    end
end
end
