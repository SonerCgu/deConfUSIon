function label = deConfUSIon_display_name_from_sources(seedName, dataStruct, matFile)
% Build readable Studio dropdown labels without losing animal/scan identity.
% Examples:
%   1005_scan3_raw
%   1005_scan3_frameRej_20260527_104500
%   1005_scan3_scrub_DVARS_linear_20260527_104500
%   1005_scan3_despike_z5_20260527_104500

if nargin < 1 || isempty(seedName), seedName = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end

try, seedName = char(seedName); catch, seedName = 'dataset'; end
try, matFile  = char(matFile);  catch, matFile = ''; end

[~,fileStem]=fileparts(matFile);
pieces = {seedName, fileStem};

try
    if isstruct(dataStruct)
        flds = {'HUMOR_fullDisplayName','displayNameFull','preprocDisplayName', ...
                'fullDisplayName','sourceDisplayName','sourceDatasetName', ...
                'sourceFileName','sourcePath','savedFile','lazyFile','preprocessing'};
        for i = 1:numel(flds)
            f = flds{i};
            if isfield(dataStruct,f) && ~isempty(dataStruct.(f))
                try
                    piece=char(dataStruct.(f));
                    if any(strcmp(f,{'sourceFileName','sourcePath','savedFile','lazyFile'}))
                        [~,piece]=fileparts(piece);
                    end
                    pieces{end+1}=piece; %#ok<AGROW>
                catch
                end
            end
        end
    end
catch
end

combo = strjoin(pieces,'_');
combo = strrep(combo,'...','_');
low = lower(combo);

% Keep existing timestamp only. Do not invent unstable timestamps during refresh.
tsList = regexp(combo,'(?:19|20)\d{6}_\d{6}','match');
if isempty(tsList)
    ts = '';
else
    ts = tsList{end};
end

animal   = local_animal(combo);
scanTag  = local_scan(combo);
sessTag  = local_session(combo);
sliceTag = local_slice(combo, dataStruct);

if isempty(animal)
    animal = local_fallback_identity(seedName);
    % A repeated acquisition suffix is not another scan. Keep a distinct FUS
    % timestamp only when the animal/session stem does not already contain it.
    if strncmpi(scanTag,'FUS_',4)
        stamp=scanTag(5:end);
        animal=regexprep(animal,'(?:_FUS_\d+)+$','','ignorecase');
        if ~isempty(regexp(animal,['(^|_)' regexptranslate('escape',stamp) '$'],'once')), scanTag=''; end
    elseif ~isempty(scanTag) && endsWith(animal,['_' scanTag],'IgnoreCase',true)
        animal=animal(1:end-numel(scanTag)-1);
    end
end

ops = {};

% Frame rejection.
if local_has_frame_rej(combo)
    ops{end+1} = 'frameRej'; %#ok<AGROW>
end

% Scrubbing.
scrubTag = local_scrub_tag(combo);
if ~isempty(scrubTag)
    ops{end+1} = scrubTag; %#ok<AGROW>
end

% Despike.
despikeTag = local_despike_tag(combo, dataStruct);
if ~isempty(despikeTag)
    ops{end+1} = despikeTag; %#ok<AGROW>
end

% Motor.
if ~isempty(regexpi(combo,'(^|[_\s-])motor([_\s-]|$)')) || ~isempty(strfind(low,'splitmotor'))
    ops{end+1} = 'motor'; %#ok<AGROW>
end

% Drift compensation.
driftTag = local_drift_tag(combo, dataStruct);
if ~isempty(driftTag)
    ops{end+1} = driftTag; %#ok<AGROW>
end

% PCA / ICA.
pcaTag = local_component_tag(combo, dataStruct, 'pca', 'PC');
if ~isempty(pcaTag), ops{end+1} = pcaTag; end %#ok<AGROW>

icaTag = local_component_tag(combo, dataStruct, 'ica', 'IC');
if ~isempty(icaTag), ops{end+1} = icaTag; end %#ok<AGROW>

% Imreg demons.
imTok = regexp(combo,'imreg(?:demons)?[^_\x2F\\-]*(?:med|median)?[^_\x2F\\-]*n\d+','match','once','ignorecase');
if isempty(imTok)
    imTok = regexp(combo,'imreg(?:demons)?[_-]?(?:med|median)?[_-]?n\d+','match','once','ignorecase');
end
if ~isempty(imTok)
    nTok = regexp(imTok,'n\d+','match','once','ignorecase');
    if isempty(nTok), nTok = 'n25'; end
    ops{end+1} = ['imreg_med_' nTok]; %#ok<AGROW>
elseif ~isempty(regexpi(combo,'imreg|demons','once'))
    ops{end+1}='imreg';
end

% Filtering.
fTok = regexp(combo,'(?:BPF[^_]*to[^_]*Hz_o\d+|LPF[^_]*Hz_o\d+|HPF[^_]*Hz_o\d+|BSF[^_]*to[^_]*Hz_o\d+)(?:_(?:butter|cheby1|cheby2|ellip|fir|fft))?','match','once','ignorecase');
if ~isempty(fTok)
    fTok = regexprep(fTok,'[^A-Za-z0-9_\-]','');
    ops{end+1} = fTok; %#ok<AGROW>
elseif ~isempty(regexpi(combo,'(^|_)BPF|(^|_)LPF|(^|_)HPF|filter','once'))
    ops{end+1}='filter';
end

% Temporal smoothing.
tTok = regexp(combo,'tsmooth_[^_]+s|temporalSmooth_[^_]+s','match','once','ignorecase');
if ~isempty(tTok)
    tTok = regexprep(tTok,'temporalSmooth_','tsmooth_','ignorecase');
    ops{end+1} = tTok; %#ok<AGROW>
end

% Subsampling.
subTok = regexp(combo,'submean[^_]*_nsub\d+|submed[^_]*_nsub\d+|subsample_[^_]*_nsub\d+','match','once','ignorecase');
if ~isempty(subTok)
    subTok = regexprep(subTok,'subsample_mean_','submean_','ignorecase');
    subTok = regexprep(subTok,'subsample_median_','submed_','ignorecase');
    ops{end+1} = subTok; %#ok<AGROW>
end

if isempty(ops)
    for operation={'pca','ica','chop','temporal','clutter','svd','drift'}
        if ~isempty(regexpi(combo,['(^|[_\s-])' operation{1}],'once'))
            ops{end+1}=operation{1}; %#ok<AGROW>
        end
    end
end
if isempty(ops)
    processed=isstruct(dataStruct) && isfield(dataStruct,'preprocessing') && ...
        ~isempty(dataStruct.preprocessing) && ~any(strcmpi(strtrim(char(dataStruct.preprocessing)),{'raw','none','unprocessed'}));
    processed=processed || ~isempty(regexpi(matFile,'[\\/]Preprocessing[\\/]|[\\/]P[\\/]','once'));
    if processed, ops={'processed'}; else, ops={'raw'}; end
end
ops = local_dedupe_ops(ops);

parts = {animal};
if ~isempty(scanTag)
    parts{end+1} = scanTag; %#ok<AGROW>
elseif ~isempty(sessTag)
    parts{end+1} = sessTag; %#ok<AGROW>
end
if ~isempty(sliceTag), parts{end+1} = sliceTag; end %#ok<AGROW>
for i = 1:numel(ops), parts{end+1} = ops{i}; end %#ok<AGROW>

if ~isempty(ts) && ~(numel(ops) == 1 && strcmpi(ops{1},'raw'))
    parts{end+1} = ts; %#ok<AGROW>
end

label = local_clean(strjoin(parts,'_'));
if isempty(label), label = 'dataset'; end
end

function tag = local_drift_tag(combo, dataStruct)
% Detailed Drift Compensation label for Studio and Load Data dropdowns.
tag = '';
try
    if isstruct(dataStruct) && isfield(dataStruct,'driftStats') && ~isempty(dataStruct.driftStats)
        st = dataStruct.driftStats;
        m = 'drift';
        if isfield(st,'method') && ~isempty(st.method)
            m = lower(char(st.method));
        end

        tag = ['driftComp_' m];

        if isfield(st,'polyOrder') && ~isempty(st.polyOrder) && isfinite(double(st.polyOrder))
            po = round(double(st.polyOrder));
            switch po
                case 0, ord = 'constant';
                case 1, ord = 'linear';
                case 2, ord = 'quadratic';
                case 3, ord = 'cubic';
                otherwise, ord = ['order' num2str(po)];
            end
            if any(strcmp(m,{'glm','model','anchor','baseline','poly','robust','irls'}))
                tag = [tag '_' ord '_o' num2str(po)];
            end
        end

        if isfield(st,'baselineSec') && numel(st.baselineSec) == 2
            tag = [tag '_b' local_numtag(st.baselineSec(1)) '-' local_numtag(st.baselineSec(2))];
        end

        if any(strcmp(m,{'glm','model'}))
            if isfield(st,'injectionSec') && ~isempty(st.injectionSec)
                tag = [tag '_inj' local_numtag(st.injectionSec(1))];
            end
            if isfield(st,'responseSec') && ~isempty(st.responseSec)
                tag = [tag '_resp' local_numtag(st.responseSec(1))];
            end
        elseif strcmp(m,'anchor') && isfield(st,'tailSec') && numel(st.tailSec) == 2
            tag = [tag '_tail' local_numtag(st.tailSec(1)) '-' local_numtag(st.tailSec(2))];
        elseif any(strcmp(m,{'compcor','acompcor'})) && isfield(st,'nComp')
            tag = [tag '_nC' num2str(round(double(st.nComp)))];
        end

        if isfield(st,'restoreMode') && ~isempty(st.restoreMode)
            tag = [tag '_restore' lower(regexprep(char(st.restoreMode),'[^A-Za-z0-9]',''))];
        end
        return;
    end

    tok = regexp(combo,'DRIFTCOMP[_-]([A-Za-z]+)','tokens','once','ignorecase');
    if ~isempty(tok)
        tag = ['driftComp_' lower(tok{1})];
    elseif ~isempty(regexpi(combo,'(^|[_\s-])driftcomp|drift_comp|driftcompensat'))
        tag = 'driftComp';
    end
catch
    tag = '';
end
end

function s = local_numtag(x)
s = num2str(x,'%.6g');
s = strrep(s,'.','p');
s = strrep(s,'-','m');
end

function animal = local_animal(combo)
animal = '';
try
    tok = regexp(combo,'B6J?[_-](\d{3,6})','tokens','once','ignorecase');
    if isempty(tok), tok = regexp(combo,'(?:^|[_\x2F\\-])(\d{3,6})[_-]scan','tokens','once','ignorecase'); end
    if isempty(tok), tok = regexp(combo,'(?:^|[_\x2F\\-])(\d{3,6})[_-]sess','tokens','once','ignorecase'); end
    if isempty(tok), tok = regexp(combo,'(?:^|[_\x2F\\-])(\d{3,6})[_-]Session','tokens','once'); end
    if isempty(tok), tok = regexp(combo,'(?:^|[_\x2F\\-])(\d{3,6})[_-]T\d+','tokens','once','ignorecase'); end
    if ~isempty(tok), animal = tok{1}; end
catch
    animal = '';
end
end

function scanTag = local_scan(combo)
scanTag = '';
try
    tok = regexp(combo,'scan[_-]?0*(\d+)','tokens','once','ignorecase');
    if ~isempty(tok)
        scanTag = sprintf('scan%d',str2double(tok{1}));
    else
        % Acquisition files often use FUS_###### as the scan identifier.
        tok = regexp(combo,'FUS[_-]?0*(\d+)','tokens','once','ignorecase');
        if ~isempty(tok), scanTag = sprintf('FUS_%s',tok{1}); end
    end
catch
    scanTag = '';
end
end

function sessTag = local_session(combo)
sessTag = '';
try
    tok = regexp(combo,'sess(?:ion)?[_-]?0*(\d+)','tokens','once','ignorecase');
    if isempty(tok), tok = regexp(combo,'Session[_-]?0*(\d+)','tokens','once'); end
    if ~isempty(tok), sessTag = sprintf('sess%03d',str2double(tok{1})); end
catch
    sessTag = '';
end
end

function sliceTag = local_slice(combo, dataStruct)
sliceTag = '';
try
    if isstruct(dataStruct)
        if isfield(dataStruct,'pcaStats') && isfield(dataStruct.pcaStats,'sliceScope')
            sc = dataStruct.pcaStats.sliceScope;
            if isfield(sc,'sliceSpecific') && sc.sliceSpecific
                sliceTag = sprintf('sl%03dof%03d',round(sc.zIndex),round(sc.nSlices));
                return;
            end
        end
        if isfield(dataStruct,'icaStats') && isfield(dataStruct.icaStats,'sliceScope')
            sc = dataStruct.icaStats.sliceScope;
            if isfield(sc,'sliceSpecific') && sc.sliceSpecific
                sliceTag = sprintf('sl%03dof%03d',round(sc.zIndex),round(sc.nSlices));
                return;
            end
        end
    end
    tok = regexp(combo,'Slice0*(\d+)of0*(\d+)','tokens','once','ignorecase');
    if isempty(tok), tok = regexp(combo,'sl0*(\d+)of0*(\d+)','tokens','once','ignorecase'); end
    if ~isempty(tok), sliceTag = sprintf('sl%03dof%03d',str2double(tok{1}),str2double(tok{2})); end
catch
    sliceTag = '';
end
end

function tf = local_has_frame_rej(combo)
tf = ~isempty(regexpi(combo,'frame\s*[-_]?\s*rej|framerej|frame\s*[-_]?\s*rejection|frame-rate rejection|frame rate rejection'));
end

function tag = local_scrub_tag(combo)
tag = '';
try
    tok = regexp(combo,'scrub[_-]([A-Za-z0-9]+)[_-]([A-Za-z0-9]+)','tokens','once','ignorecase');
    if ~isempty(tok)
        tag = ['scrub_' tok{1} '_' lower(tok{2})];
    elseif ~isempty(regexpi(combo,'(^|[_\s-])scrub|dvars'))
        tag = 'scrub';
    end
catch
    tag = '';
end
end

function tag = local_despike_tag(combo, dataStruct)
tag = '';
try
    tok = regexp(combo,'despike[_-]?z([0-9pPmM\.\-]+)','tokens','once','ignorecase');
    if ~isempty(tok)
        z = tok{1};
        z = strrep(z,'.','p');
        z = strrep(z,'-','m');
        tag = ['despike_z' z];
        return;
    end
    if ~isempty(regexpi(combo,'(^|[_\s-])despike|despiking|despiked'))
        tag = 'despike';
    end
    if strcmp(tag,'despike') && isstruct(dataStruct) && isfield(dataStruct,'despikeZ') && ~isempty(dataStruct.despikeZ)
        z = num2str(dataStruct.despikeZ,'%.6g');
        z = strrep(z,'.','p');
        z = strrep(z,'-','m');
        tag = ['despike_z' z];
    end
catch
    tag = '';
end
end

function tag = local_component_tag(combo, dataStruct, prefix, compName)
tag = '';
try
    if strcmpi(prefix,'pca')
        tok = regexp(combo,'pca[_-]?dropPC[0-9\-]+|dropPC[0-9\-]+|pca_done','match','once','ignorecase');
    else
        tok = regexp(combo,'ica[_-]?dropIC[0-9\-]+|dropIC[0-9\-]+|ica_done','match','once','ignorecase');
    end
    if ~isempty(tok)
        tok = regexprep(tok,['^drop' compName],[prefix '_drop' compName],'ignorecase');
        tok = regexprep(tok,[prefix '[_-]+'],[prefix '_'],'ignorecase');
        tag = tok;
        return;
    end
    if isstruct(dataStruct)
        statsField = [lower(prefix) 'Stats'];
        if isfield(dataStruct,statsField)
            stats = dataStruct.(statsField);
            tag = [prefix '_done'];
            if isfield(stats,'selectedComponents') && ~isempty(stats.selectedComponents)
                tag = [prefix '_drop' compName local_range(stats.selectedComponents)];
            end
        end
    end
catch
    tag = '';
end
end

function s = local_range(v)
v = sort(unique(v(:)'));
if isempty(v), s = 'unknown'; return; end
pieces = {};
i = 1;
while i <= numel(v)
    j = i;
    while j < numel(v) && v(j+1) == v(j)+1, j = j + 1; end
    if i == j
        pieces{end+1} = sprintf('%d',v(i)); %#ok<AGROW>
    else
        pieces{end+1} = sprintf('%d-%d',v(i),v(j)); %#ok<AGROW>
    end
    i = j + 1;
end
s = strjoin(pieces,'-');
end

function opsOut = local_dedupe_ops(ops)
opsOut = {};
seen = {};
for i = 1:numel(ops)
    op = local_clean(ops{i});
    low = lower(op);
    if isempty(op), continue; end
    if ~isempty(strfind(low,'framerej')) || ~isempty(strfind(low,'frame_rej')), cls = 'frameRej';
    elseif ~isempty(strfind(low,'scrub')) || ~isempty(strfind(low,'dvars')), cls = 'scrub';
    elseif ~isempty(strfind(low,'despike')), cls = 'despike';
    elseif ~isempty(strfind(low,'driftcomp')), cls = 'driftComp';
    elseif ~isempty(strfind(low,'pca')), cls = 'pca';
    elseif ~isempty(strfind(low,'ica')), cls = 'ica';
    elseif ~isempty(strfind(low,'imreg')), cls = 'imreg';
    elseif ~isempty(strfind(low,'motor')), cls = 'motor';
    elseif strcmp(low,'raw'), cls = 'raw';
    elseif ~isempty(strfind(low,'bpf')) || ~isempty(strfind(low,'lpf')) || ~isempty(strfind(low,'hpf')), cls = 'filter';
    elseif ~isempty(strfind(low,'tsmooth')), cls = 'tsmooth';
    elseif ~isempty(strfind(low,'sub')), cls = 'subsample';
    else, cls = low;
    end
    if ~any(strcmp(seen,cls))
        opsOut{end+1} = op; %#ok<AGROW>
        seen{end+1} = cls; %#ok<AGROW>
    end
end
end

function id = local_fallback_identity(seedName)
id = '';
try
    id = char(seedName);
    id = strrep(id,'...','_');
    id = regexprep(id,'\.nii\.gz$','','ignorecase');
    id = regexprep(id,'\.nii$','','ignorecase');
    id = regexprep(id,'\.mat$','','ignorecase');
    id = regexprep(id,'_(?:19|20)\d{6}_\d{6}$','');
    % Acquisition identifiers sometimes contain the whole file stem twice.
    % The first FUS timestamp already ends the animal/session identity;
    % local_scan appends that scan identifier exactly once below.
    id = regexprep(id,'_FUS[_-]?\d+.*$','','ignorecase');
    id = regexprep(id,'_(raw|processed|frameRej|framerej|scrub|despike|motor|pca|ica|imreg|BPF|LPF|HPF|tsmooth|subsample|submean|submed|filter|temporal|chop|clutter|svd|drift).*$','','ignorecase');
    id = regexprep(id,'[^A-Za-z0-9_\-]','_');
    id = regexprep(id,'_+','_');
    id = regexprep(id,'^_+|_+$','');
catch
    id = '';
end
if isempty(id), id = 'dataset'; end
end

function out = local_clean(in)
out = char(in);
out = strrep(out,'...','_');
out = regexprep(out,'\.nii\.gz$','','ignorecase');
out = regexprep(out,'\.nii$','','ignorecase');
out = regexprep(out,'\.mat$','','ignorecase');
out = regexprep(out,'^preproc_preproc_','','ignorecase');
out = regexprep(out,'^preproc_','','ignorecase');
out = regexprep(out,'T0+\d+','','ignorecase');
out = regexprep(out,'too1','','ignorecase');
out = regexprep(out,'_0000[0-9a-fA-F]{4,}','');
out = regexprep(out,'_[0-9a-fA-F]{8}(?=_|$)','');
out = regexprep(out,'raw_(?=.*(?:frameRej|framerej|scrub|despike|motor|pca|ica|imreg|BPF|LPF|HPF|tsmooth|sub))','','ignorecase');
out = regexprep(out,'frame_rej','frameRej','ignorecase');
out = regexprep(out,'framerej','frameRej','ignorecase');
out = regexprep(out,'despike_despike','despike','ignorecase');
out = regexprep(out,'motor_motor','motor','ignorecase');
out = regexprep(out,'imreg_imreg','imreg','ignorecase');
out = regexprep(out,'pca_pca','pca','ignorecase');
out = regexprep(out,'ica_ica','ica','ignorecase');
out = regexprep(out,'[^A-Za-z0-9_\-\.]+','_');
out = regexprep(out,'_+','_');
out = regexprep(out,'^_+|_+$','');
end
