function savePath = deConfUSIon_safe_preproc_save_path(preFolder, fullName, keyName, opTag)
% Short physical filename to avoid Windows/network path errors.
% The readable chain is stored in displayNameFull/preprocDisplayName.

if nargin < 1 || isempty(preFolder), preFolder = pwd; end
if nargin < 2 || isempty(fullName),  fullName  = 'dataset'; end
if nargin < 3 || isempty(keyName),   keyName   = fullName; end
if nargin < 4 || isempty(opTag),     opTag     = 'preproc'; end

try, if isstring(preFolder), preFolder = char(preFolder); end, catch, end
try, if isstring(fullName),  fullName  = char(fullName);  end, catch, end
try, if isstring(keyName),   keyName   = char(keyName);   end, catch, end
try, if isstring(opTag),     opTag     = char(opTag);     end, catch, end

% Resolve the name without writing. DataIO creates the directory only after
% retaining the completed result, so an unavailable drive can be retried.

% The explicit operation is the step being saved, not one of its ancestors.
% Older code searched the whole chain for PCA first, so even GLM/imreg outputs
% could receive a PCA or imreg filename. Generic legacy callers use the last tag.
op = lower(char(opTag));
if strcmp(op,'preproc')
    [~,~,tokens]=regexp(fullName,'(?:^|_)(pca|ica|imreg(?:demons)?|driftComp|DRIFTCOMP|frameRej|scrub|despike|motor|BPF|LPF|HPF|tsmooth|submean|submed|subsample|SVD)(?=[_\-]|$)','start','end','tokens','ignorecase');
    if ~isempty(tokens), op=lower(tokens{end}{1}); end
end
switch op
    case {'imreg','imregdemons'}
        opTag='imreg'; pattern='imreg(?:demons)?[_-]?(?:med|median|mean)?[_-]?n\d+';
    case {'drift','driftcomp'}
        opTag='drift'; pattern='driftcomp[_-][A-Za-z]+';
    case 'pca'
        opTag='pca'; pattern='dropPC[^_]*';
    case 'ica'
        opTag='ica'; pattern='dropIC[^_]*';
    case {'framerej','frame_rej'}
        opTag='framerej'; pattern='frameRej';
    case 'scrub'
        opTag='scrub'; pattern='scrub_[A-Za-z0-9]+_[A-Za-z0-9]+';
    case 'despike'
        opTag='despike'; pattern='despike_z[0-9pPmM.\-]+';
    case {'filter','bpf','lpf','hpf'}
        opTag='filter'; pattern='BPF[^_]*to[^_]*Hz_o\d+|LPF[^_]*Hz_o\d+|HPF[^_]*Hz_o\d+';
    case {'submean','submed','subsample'}
        opTag='subsample'; pattern='sub(?:mean|med)[^_]*_nsub\d+|subsample_[^_]*_nsub\d+';
    case 'tsmooth'
        opTag='tsmooth'; pattern='tsmooth_[^_]+s|temporalSmooth_[^_]+s';
    otherwise
        opTag=op; pattern='';
end
tag=opTag;
if ~isempty(pattern)
    matches=regexp(fullName,pattern,'match','ignorecase');
    if ~isempty(matches), tag=matches{end}; end
end
if any(strcmp(opTag,{'pca','ica'}))
    sl=regexp(fullName,'sl\d+of\d+|slice\d+of\d+','match','once','ignorecase');
    tag=local_join(sl,tag);
end

if isempty(tag), tag = opTag; end
tag = regexprep(tag,'[^A-Za-z0-9_\-]','_');
tag = regexprep(tag,'_+','_');
tag = regexprep(tag,'^_+|_+$','');

tokTS = regexp(fullName,'\d{8}_\d{6}','match');
if isempty(tokTS), ts = datestr(now,'yyyymmdd_HHMMSS'); else, ts = tokTS{end}; end

h = local_hash([fullName '_' keyName]);
base = sprintf('%s_%s_%s_%s', opTag, tag, ts, h);
base = regexprep(base,'[^A-Za-z0-9_\-]','_');
base = regexprep(base,'_+','_');
base = regexprep(base,'^_+|_+$','');
if numel(base) > 90, base = [base(1:78) '_' h]; end

savePath = fullfile(preFolder,[base '.mat']);

if numel(savePath) > 240
    [parentFolder,thisFolder] = fileparts(preFolder);
    if strcmpi(thisFolder,'Preprocessing'), shortFolder = fullfile(parentFolder,'P'); else, shortFolder = fullfile(preFolder,'P'); end
    base = sprintf('%s_%s_%s', opTag, tag, h);
    if numel(base) > 75, base = [base(1:64) '_' h]; end
    savePath = fullfile(shortFolder,[base '.mat']);
end

if exist(savePath,'file') == 2
    [folder,base2,ext] = fileparts(savePath);
    for k = 1:999
        cand = fullfile(folder,sprintf('%s_%03d%s',base2,k,ext));
        if exist(cand,'file') ~= 2, savePath = cand; break; end
    end
end
end

function out = local_join(a,b)
out = '';
if ~isempty(a), out = a; end
if ~isempty(b)
    if isempty(out), out = b; else, out = [out '_' b]; end
end
end

function h = local_hash(s)
try
    md = java.security.MessageDigest.getInstance('MD5');
    md.update(uint8(s(:)'));
    d = typecast(md.digest,'uint8');
    hx = lower(reshape(dec2hex(d,2).',1,[]));
    h = hx(1:8);
catch
    h = sprintf('%08x', mod(sum(uint32(s)), 2^32));
end
end
