
% GA_FISHERZ_STATS_PATCH_20260512
% FC group matrices are averaged/statistically compared in Fisher z space.
% Convert back with tanh(Z) only for Pearson-r display if needed.
function varargout = GroupAnalysis_FC(action, varargin)

if nargin < 1 || isempty(action)
    error('GroupAnalysis_FC requires an action string.');
end

actionIn = strtrim(char(action));
fnLocal = resolveLocalActionName_GA_dispatch(actionIn);

if isempty(fnLocal)
    error('Unknown GroupAnalysis_FC action: %s', actionIn);
end

fh = str2func(fnLocal);

try
    if nargout == 0
        fh(varargin{:});
    else
        [varargout{1:nargout}] = fh(varargin{:});
    end
catch ME
    try, GA_printErrorLocal(ME,'caught error in GroupAnalysis_FC.m'); catch, end
    ga_print_module_error_local(ME, actionIn, fnLocal, 'GroupAnalysis_FC');
    rethrow(ME);
end
end

function ga_print_module_error_local(ME, actionIn, fnLocal, moduleName)
% Print full module errors in Command Window.
try
    nl = char(10);
    sep = repmat('=', 1, 70);
    fprintf(2, '%s%c', sep, 10);
    fprintf(2, 'ERROR in %s action: %s%c', moduleName, actionIn, 10);
    fprintf(2, 'Local function: %s%c', fnLocal, 10);
    fprintf(2, 'Message: %s%c', ME.message, 10);
    fprintf(2, '%s%c', sep, 10);
    try
        fprintf(2, '%s%c', getReport(ME, 'extended', 'hyperlinks', 'on'), 10);
    catch
        for kk = 1:numel(ME.stack)
            fprintf(2, '  %s | line %d | %s%c', ...
                ME.stack(kk).name, ME.stack(kk).line, ME.stack(kk).file, 10);
        end
    end
    fprintf(2, '%s%c%c', sep, 10, 10);
catch
    try
        fprintf(2, 'GroupAnalysis module error: %s%c', ME.message, 10);
    catch
    end
end
end

function fnLocal = resolveLocalActionName_GA_dispatch(actionIn)
fnLocal = '';

try
    thisFile = [mfilename('fullpath') '.m'];
    txtLocal = fileread(thisFile);
catch
    return;
end

% Collect all function names in this module.
tok = regexp(txtLocal, '(?m)^\s*function\s+(?:\[[^\]]*\]\s*=\s*|[A-Za-z]\w*\s*=\s*)?([A-Za-z]\w*)\s*(?:\(|$)', 'tokens');

if isempty(tok)
    return;
end

names = cell(size(tok));
for ii = 1:numel(tok)
    names{ii} = tok{ii}{1};
end

skip = strcmpi(names, mfilename) | strcmpi(names, 'resolveLocalActionName_GA_dispatch');
names = names(~skip);

% First try exact case-insensitive match.
hit = find(strcmpi(names, actionIn), 1, 'first');
if ~isempty(hit)
    fnLocal = names{hit};
    return;
end

% Then try normalized match: removes underscores, spaces, dashes, punctuation.
normAction = lower(regexprep(actionIn, '[^A-Za-z0-9]', ''));
for ii = 1:numel(names)
    normName = lower(regexprep(names{ii}, '[^A-Za-z0-9]', ''));
    if strcmp(normName, normAction)
        fnLocal = names{ii};
        return;
    end
end
end


% =====================================================================
% COPIED LOCAL FUNCTIONS FROM GroupAnalysis.m
% =====================================================================

function fileList = findFCBundlesRecursive(rootDir)
fileList = {};

if nargin < 1 || isempty(rootDir) || exist(rootDir,'dir') ~= 7
    return;
end

d = dir(fullfile(rootDir,'FC_GroupBundle_*.mat'));
for i = 1:numel(d)
    fileList{end+1,1} = fullfile(d(i).folder,d(i).name); %#ok<AGROW>
end

sub = dir(rootDir);
for i = 1:numel(sub)
    if ~sub(i).isdir
        continue;
    end

    nm = sub(i).name;
    if strcmp(nm,'.') || strcmp(nm,'..')
        continue;
    end

    more = findFCBundlesRecursive(fullfile(rootDir,nm));
    if ~isempty(more)
        fileList = [fileList; more(:)]; %#ok<AGROW>
    end
end
end

function tf = isFCGroupBundleFile(fp)
tf = false;

if nargin < 1 || isempty(fp) || exist(fp,'file') ~= 2
    return;
end

try
    info = whos('-file',fp);
    vars = {info.name};
    if any(strcmp(vars,'fcBundle'))
        tf = true;
        return;
    end
catch
end

[~,nm,ext] = fileparts(fp);
if strcmpi(ext,'.mat') && ~isempty(regexpi(nm,'^FC_GroupBundle_','once'))
    tf = true;
end
end

function [B, cache] = getCachedFCBundle(cache, fp)
key = makeCacheKey('FCBUNDLE',fp);

if isstruct(cache) && isfield(cache,'fcBundle') && isa(cache.fcBundle,'containers.Map')
    try
        if isKey(cache.fcBundle,key)
            B = cache.fcBundle(key);
            return;
        end
    catch
    end
end

L = load(fp);

if isfield(L,'fcBundle')
    B = L.fcBundle;
else
    error('File does not contain variable fcBundle: %s', fp);
end

if ~isstruct(B) || ~isfield(B,'subjects')
    error('Invalid FC group bundle: %s', fp);
end

if isstruct(cache) && isfield(cache,'fcBundle') && isa(cache.fcBundle,'containers.Map')
    try
        cache.fcBundle(key) = B;
    catch
    end
end
end

function [FC, cache] = loadFCGroupBundlesFromFiles(fileList, cache)
FC = struct();
FC.files = fileList(:);
FC.subjects = struct([]);
FC.nSubjects = 0;

idx = 0;

for i = 1:numel(fileList)
    fp = fileList{i};

    if ~isFCGroupBundleFile(fp)
        continue;
    end

    [B, cache] = getCachedFCBundle(cache, fp);

    for j = 1:numel(B.subjects)
        subj = B.subjects(j);

        if ~isfield(subj,'labels') || isempty(subj.labels), continue; end
        if ~isfield(subj,'R')      || isempty(subj.R),      continue; end

        idx = idx + 1;
        FC.subjects(idx).sourceFile = fp;

        if isfield(subj,'name') && ~isempty(subj.name)
            FC.subjects(idx).name = strtrimSafe(subj.name);
        else
            FC.subjects(idx).name = sprintf('FC_Subject_%02d',idx);
        end

        if isfield(subj,'group') && ~isempty(subj.group)
            FC.subjects(idx).group = strtrimSafe(subj.group);
        else
            FC.subjects(idx).group = inferFCGroupFromText([FC.subjects(idx).name ' ' fp]);
        end
        if isempty(FC.subjects(idx).group) || strcmpi(FC.subjects(idx).group,'All')
            FC.subjects(idx).group = inferFCGroupFromText([FC.subjects(idx).name ' ' fp]);
        end

        FC.subjects(idx).labels = double(subj.labels(:));

        if isfield(subj,'names') && ~isempty(subj.names)
            FC.subjects(idx).names = subj.names(:);
        else
            FC.subjects(idx).names = makeDefaultFCNames(FC.subjects(idx).labels);
        end

        FC.subjects(idx).R = double(subj.R);

        if isfield(subj,'Z') && ~isempty(subj.Z)
            FC.subjects(idx).Z = double(subj.Z);
        else
            Rtmp = max(-0.999999,min(0.999999,double(subj.R)));
            Ztmp = atanh(Rtmp);
            Ztmp(1:size(Ztmp,1)+1:end) = 0;
            FC.subjects(idx).Z = Ztmp;
        end

        % Preserve step-motor / slice-specific FC fields.
        FC.subjects(idx).isStepMotor3D = isfield(subj,'isStepMotor3D') && logical(subj.isStepMotor3D);
        if isfield(subj,'nSlices') && ~isempty(subj.nSlices)
            FC.subjects(idx).nSlices = double(subj.nSlices);
        else
            FC.subjects(idx).nSlices = [];
        end
        if isfield(subj,'sliceResults') && ~isempty(subj.sliceResults)
            FC.subjects(idx).sliceResults = subj.sliceResults;
        else
            FC.subjects(idx).sliceResults = struct([]);
        end

        % Preserve display-mode fields.
        if isfield(subj,'displayMatrix') && ~isempty(subj.displayMatrix)
            FC.subjects(idx).displayMatrix = double(subj.displayMatrix);
        else
            FC.subjects(idx).displayMatrix = FC.subjects(idx).R;
        end
        if isfield(subj,'displayZ') && ~isempty(subj.displayZ)
            FC.subjects(idx).displayZ = double(subj.displayZ);
        else
            FC.subjects(idx).displayZ = FC.subjects(idx).Z;
        end
        if isfield(subj,'displayNames') && ~isempty(subj.displayNames)
            FC.subjects(idx).displayNames = subj.displayNames(:);
        else
            FC.subjects(idx).displayNames = FC.subjects(idx).names;
        end
        if isfield(subj,'displayLabels') && ~isempty(subj.displayLabels)
            FC.subjects(idx).displayLabels = double(subj.displayLabels(:));
        else
            FC.subjects(idx).displayLabels = FC.subjects(idx).labels;
        end

        % Preserve provenance and rich payloads.
        if isfield(subj,'TR') && ~isempty(subj.TR), FC.subjects(idx).TR = double(subj.TR); else, FC.subjects(idx).TR = []; end
        if isfield(subj,'analysisDir') && ~isempty(subj.analysisDir), FC.subjects(idx).analysisDir = subj.analysisDir; else, FC.subjects(idx).analysisDir = ''; end
        if isfield(subj,'meanTS'), FC.subjects(idx).meanTS = subj.meanTS; else, FC.subjects(idx).meanTS = []; end
        if isfield(subj,'counts'), FC.subjects(idx).counts = subj.counts; else, FC.subjects(idx).counts = []; end
        if isfield(subj,'timeIdx'), FC.subjects(idx).timeIdx = subj.timeIdx; else, FC.subjects(idx).timeIdx = []; end
        if isfield(subj,'heatmap'), FC.subjects(idx).heatmap = subj.heatmap; else, FC.subjects(idx).heatmap = struct(); end
        if isfield(subj,'compareROI'), FC.subjects(idx).compareROI = subj.compareROI; else, FC.subjects(idx).compareROI = struct(); end
        if isfield(subj,'seedResults'), FC.subjects(idx).seedResults = subj.seedResults; else, FC.subjects(idx).seedResults = struct([]); end
        if isfield(subj,'allEpochs'), FC.subjects(idx).allEpochs = subj.allEpochs; else, FC.subjects(idx).allEpochs = struct([]); end
    end
end

FC.nSubjects = idx;
end

function names = makeDefaultFCNames(labels)
names = cell(numel(labels),1);
for i = 1:numel(labels)
    names{i} = sprintf('ROI_%g',labels(i));
end
end

function g = inferFCGroupFromText(txt)
g = 'Unassigned';

u = upper(strtrimSafe(txt));

if contains(u,'PACAP') || contains(u,'GROUPA') || contains(u,'CONDA')
    g = 'PACAP';
elseif contains(u,'VEHICLE') || contains(u,'VEH') || contains(u,'CONTROL') || contains(u,'GROUPB') || contains(u,'CONDB')
    g = 'Vehicle';
end
end

function s = strtrimSafe(x)
try
    if isempty(x)
        s = '';
    else
        s = strtrim(char(x));
    end
catch
    s = '';
end
end

function key = makeCacheKey(varargin)
parts = cellfun(@(x) strtrimSafe(x), varargin, 'UniformOutput', false);
key = strjoin(parts,'||');
end
