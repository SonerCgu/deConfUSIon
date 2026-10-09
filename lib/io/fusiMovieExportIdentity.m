function identity=fusiMovieExportIdentity(par,label,includeSequence)
% Export provenance uses the active signal scan, regardless of the underlay.
% Descriptors/labels only: naming never reads a movie array from disk.
if nargin<3,includeSequence=false;end
if nargin<2,label='';end
if ~isstruct(par),par=struct();end
scans=struct('label',{},'rawFile',{},'processedFile',{},'key',{},'scan',{});
q=[];if isfield(par,'scanSequence'),q=par.scanSequence;end
if isstruct(q)&&isfield(q,'scans')&&iscell(q.scans)&&~isempty(q.scans)&&isfield(q,'active')
    chosen=q.active;
    if includeSequence,chosen=find(fusiScanSequence('included',q));end
    for k=chosen
        d=q.scans{k};raw=fieldText(d,{'rawFile'});file=fieldText(d,{'file'});
        name=fieldText(d,{'label'});if isempty(name),name=char(label);end
        selected=entry(name,raw,file,fieldText(d,{'key'}));
        if k==q.active
            % Initial descriptors from older Studio windows can say only
            % 'scan9'. Prefer that same scan's full dropdown label.
            candidates={fieldText(par,{'datasetTag','activeDataset'}),char(label)};
            for ci=1:numel(candidates)
                candidate=entry(candidates{ci},'',file,'');
                if ~isempty(candidates{ci})&&strcmpi(candidate.scan,selected.scan)&&hasProcessing(candidate.label)
                    selected.label=candidate.label;break;
                end
            end
        end
        if ~hasProcessing(selected.label)&&isfile(file)
            metadata=deConfUSIon_read_processing_metadata(file);
            recovered=fieldText(metadata,{'HUMOR_fullDisplayName','displayNameFull','preprocDisplayName','preprocessing'});
            if isempty(recovered),[~,recovered]=fileparts(file);end
            if hasProcessing(recovered),selected.label=[selected.scan ' | ' recovered];end
        end
        scans(end+1)=selected; %#ok<AGROW>
    end
end
if isempty(scans)
    name=fieldText(par,{'datasetTag','activeDataset'});if isempty(name),name=char(label);end
    raw=fieldText(par,{'loadedFile','sourceFile'});
    file=fieldText(par,{'fusiSequencePowerFile'});
    scans=entry(name,raw,file,file);
end
names=cell(1,numel(scans));
for k=1:numel(scans)
    name=deConfUSIon_compact_chain_name(scans(k).label);
    token=regexpi(name,'(?:^|_)scan\d+(?:_ES)?(?=_|$)','start','once');
    if ~isempty(token)
        if name(token)=='_',token=token+1;end
        name=name(token:end);
    elseif ~isempty(scans(k).scan),name=[scans(k).scan '_' name];end
    names{k}=name;
end
name=strjoin(unique(names,'stable'),'__');
if includeSequence&&numel(scans)>1
    ids={scans.scan};numbers=nan(1,numel(ids));
    for k=1:numel(ids),token=regexp(ids{k},'^scan(\d+)$','tokens','once');if ~isempty(token),numbers(k)=str2double(token{1});end,end
    if all(isfinite(numbers))
        if all(diff(numbers)==1)||all(diff(numbers)==-1),summary=sprintf('scan%d-to-scan%d',numbers(1),numbers(end));
        else,summary=['scan' strjoin(arrayfun(@num2str,numbers,'UniformOutput',false),'-')];end
        processing=regexprep(names{1},'^scan\d+_?','');
        name=['sequence_' summary];if ~isempty(processing),name=[name '_' processing];end
    else,name=['sequence_' name];end
end
identity=struct('version',1,'displayLabel',char(label),'sequence',logical(includeSequence), ...
    'nameLabel',name,'scans',scans);
end
function s=entry(name,raw,file,key)
parts=regexp(name,'^(scan\d+(?:_ES)?)\s*\|\s*(.*)$','tokens','once','ignorecase');
if ~isempty(parts)&&~isempty(regexpi(parts{2},['^' regexptranslate('escape',parts{1}) '(?:_|$)'],'once')),name=parts{2};end
scan='';
for value={raw,name,file}
    scan=regexpi(strrep(value{1},'\','/'),'(?:^|[/_\s|])scan\d+(?:_ES)?(?=[/_\s|.\-]|$)','match','once');
    scan=regexprep(scan,'^[/_\s|]+','');if ~isempty(scan),break;end
end
s=struct('label',name,'rawFile',raw,'processedFile',file,'key',key,'scan',scan);
end
function yes=hasProcessing(name)
yes=~isempty(regexpi(name,'(?:PC\d+|IC\d+|pca|ica|imreg|demons|[LBH]PF|despike|smooth|scrub|filter|SVD|raw)','once'));
end
function value=fieldText(s,names)
value='';
for k=1:numel(names)
    if isfield(s,names{k})&&(ischar(s.(names{k}))||(isstring(s.(names{k}))&&isscalar(s.(names{k}))))&&~isempty(s.(names{k}))
        value=char(s.(names{k}));return;
    end
end
end
