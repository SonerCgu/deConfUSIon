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

if exist(preFolder,'dir') ~= 7, mkdir(preFolder); end

lf = lower(fullName);
op = lower(opTag);
tag = opTag;

if strcmp(op,'pca') || ~isempty(strfind(lf,'_pca_'))
    opTag = 'pca';
    tok = regexp(fullName,'dropPC[^_]*','match','once');
    sl  = regexp(fullName,'sl\d+of\d+|slice\d+of\d+','match','once');
    tag = local_join(sl,tok);
elseif strcmp(op,'ica') || ~isempty(strfind(lf,'_ica_'))
    opTag = 'ica';
    tok = regexp(fullName,'dropIC[^_]*','match','once');
    sl  = regexp(fullName,'sl\d+of\d+|slice\d+of\d+','match','once');
    tag = local_join(sl,tok);
elseif ~isempty(strfind(lf,'framerej')) || ~isempty(strfind(lf,'frame_rej')) || ~isempty(strfind(lf,'frame-rej'))
    opTag = 'framerej';
    tag = 'framerej';
elseif ~isempty(strfind(lf,'_scrub_')) || ~isempty(strfind(lf,'scrub_')) || ~isempty(strfind(lf,'dvars'))
    opTag = 'scrub';
    tok = regexp(fullName,'scrub_[A-Za-z0-9]+_[A-Za-z0-9]+','match','once','ignorecase');
    if ~isempty(tok), tag = tok; else, tag = 'scrub'; end
elseif ~isempty(strfind(lf,'despike')) || ~isempty(strfind(lf,'despiking')) || ~isempty(strfind(lf,'despiked'))
    opTag = 'despike';
    tok = regexp(fullName,'despike_z[0-9pPmM\.\-]+','match','once','ignorecase');
    if ~isempty(tok)
        tok = strrep(tok,'.','p');
        tok = strrep(tok,'-','m');
        tag = tok;
    else
        tag = 'despike';
    end
elseif ~isempty(strfind(lf,'bpf')) || ~isempty(strfind(lf,'lpf')) || ~isempty(strfind(lf,'hpf'))
    opTag = 'filter';
    tok = regexp(fullName,'BPF[^_]*to[^_]*Hz_o\d+|LPF[^_]*Hz_o\d+|HPF[^_]*Hz_o\d+','match','once');
    if ~isempty(tok), tag = tok; end
elseif ~isempty(strfind(lf,'submean')) || ~isempty(strfind(lf,'submed')) || ~isempty(strfind(lf,'subsample'))
    opTag = 'subsample';
    tok = regexp(fullName,'sub(mean|med)[^_]*_nsub\d+|subsample_[^_]*_nsub\d+','match','once');
    if ~isempty(tok), tag = tok; end
elseif ~isempty(strfind(lf,'tsmooth')) || ~isempty(strfind(lf,'temporalsmooth'))
    opTag = 'tsmooth';
    tok = regexp(fullName,'tsmooth_[^_]+s|temporalSmooth_[^_]+s','match','once');
    if ~isempty(tok), tag = tok; end
elseif ~isempty(strfind(lf,'imreg'))
    opTag = 'imreg';
    tok = regexp(fullName,'imreg[^_]*_?(med|median)?_?n\d+','match','once');
    if ~isempty(tok), tag = tok; end
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
    if exist(shortFolder,'dir') ~= 7, mkdir(shortFolder); end
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
    hx = lower(reshape(dec2hex(d,2).','1',[]));
    h = hx(1:8);
catch
    h = sprintf('%08x', mod(sum(uint32(s)), 2^32));
end
end
