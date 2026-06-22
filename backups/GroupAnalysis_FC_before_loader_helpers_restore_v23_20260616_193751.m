
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


function key = makeCacheKey(varargin)
% Robust local cache-key helper for GroupAnalysis_FC.
% Supports calls like makeCacheKey(fp) and makeCacheKey('FCBUNDLE',fp).

if nargin < 1
    parts = {'cache'};
else
    parts = varargin;
end

s = '';
for ii = 1:numel(parts)
    x = parts{ii};
    try
        if isa(x,'string')
            x = char(x);
        end
    catch
    end
    try
        if iscell(x) && ~isempty(x)
            x = x{1};
        end
    catch
    end
    try
        if isnumeric(x) || islogical(x)
            x = mat2str(x);
        elseif ~ischar(x)
            x = evalc('disp(x)');
        end
    catch
        x = 'cache';
    end
    if isempty(x)
        x = 'cache';
    end
    s = [s '__' char(x)]; %#ok<AGROW>
end

% Simple stable hash using only base MATLAB.
h = 0;
for ii = 1:numel(s)
    h = mod(h * 131 + double(s(ii)), 2147483647);
end

base = regexprep(s,'[^A-Za-z0-9_]','_');
base = regexprep(base,'_+','_');
base = regexprep(base,'^_+','');
base = regexprep(base,'_+$','');

if isempty(base)
    base = 'cache';
end
if numel(base) > 48
    base = base(end-47:end);
end

key = sprintf('k_%s_%08X',base,round(h));
key = regexprep(key,'[^A-Za-z0-9_]','_');
if isempty(regexp(key,'^[A-Za-z]','once'))
    key = ['k_' key];
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
if nargin < 2 || isempty(cache)
    cache = struct();
end
if ischar(fileList)
    fileList = {fileList};
end
FC = struct();
FC.files = fileList(:);
FC.subjects = struct([]);
FC.nSubjects = 0;
FC.loaded = false;
idx = 0;
for i = 1:numel(fileList)
    fp = fileList{i};
    if ~isFCGroupBundleFile(fp)
        continue;
    end
    [B, cache] = getCachedFCBundle(cache, fp);
    if ~isfield(B,'subjects') || isempty(B.subjects)
        continue;
    end
    for j = 1:numel(B.subjects)
        subj = B.subjects(j);
        if ~isfield(subj,'labels') || isempty(subj.labels), continue; end
        if ~isfield(subj,'R') || isempty(subj.R), continue; end
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
        FC.subjects(idx).condition = fcGetFieldCharCompatV19(subj,'condition','');
        FC.subjects(idx).animalID = fcGetFieldCharCompatV19(subj,'animalID','');
        FC.subjects(idx).rowIndex = fcGetFieldNumCompatV19(subj,'rowIndex',NaN);
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
        FC.subjects(idx).isStepMotor3D = false;
        try, FC.subjects(idx).isStepMotor3D = isfield(subj,'isStepMotor3D') && logical(subj.isStepMotor3D); catch, end
        FC.subjects(idx).nSlices = [];
        if isfield(subj,'nSlices') && ~isempty(subj.nSlices), FC.subjects(idx).nSlices = double(subj.nSlices); end
        if isfield(subj,'sliceResults') && ~isempty(subj.sliceResults), FC.subjects(idx).sliceResults = subj.sliceResults; else, FC.subjects(idx).sliceResults = struct([]); end
        if isfield(subj,'displayMatrix') && ~isempty(subj.displayMatrix), FC.subjects(idx).displayMatrix = double(subj.displayMatrix); else, FC.subjects(idx).displayMatrix = FC.subjects(idx).R; end
        if isfield(subj,'displayZ') && ~isempty(subj.displayZ), FC.subjects(idx).displayZ = double(subj.displayZ); else, FC.subjects(idx).displayZ = FC.subjects(idx).Z; end
        if isfield(subj,'displayNames') && ~isempty(subj.displayNames), FC.subjects(idx).displayNames = subj.displayNames(:); else, FC.subjects(idx).displayNames = FC.subjects(idx).names; end
        if isfield(subj,'displayLabels') && ~isempty(subj.displayLabels), FC.subjects(idx).displayLabels = double(subj.displayLabels(:)); else, FC.subjects(idx).displayLabels = FC.subjects(idx).labels; end
        if isfield(subj,'TR') && ~isempty(subj.TR), FC.subjects(idx).TR = double(subj.TR); else, FC.subjects(idx).TR = []; end
        if isfield(subj,'analysisDir') && ~isempty(subj.analysisDir), FC.subjects(idx).analysisDir = subj.analysisDir; else, FC.subjects(idx).analysisDir = ''; end
        if isfield(subj,'meanTS'), FC.subjects(idx).meanTS = subj.meanTS; else, FC.subjects(idx).meanTS = []; end
        if isfield(subj,'roiTS'), FC.subjects(idx).roiTS = subj.roiTS; else, FC.subjects(idx).roiTS = []; end
        if isfield(subj,'timeCourses'), FC.subjects(idx).timeCourses = subj.timeCourses; else, FC.subjects(idx).timeCourses = []; end
        if isfield(subj,'counts'), FC.subjects(idx).counts = subj.counts; else, FC.subjects(idx).counts = []; end
        if isfield(subj,'timeIdx'), FC.subjects(idx).timeIdx = subj.timeIdx; else, FC.subjects(idx).timeIdx = []; end
        if isfield(subj,'heatmap'), FC.subjects(idx).heatmap = subj.heatmap; else, FC.subjects(idx).heatmap = struct(); end
        if isfield(subj,'compareROI'), FC.subjects(idx).compareROI = subj.compareROI; else, FC.subjects(idx).compareROI = struct(); end
        if isfield(subj,'seedResults'), FC.subjects(idx).seedResults = subj.seedResults; else, FC.subjects(idx).seedResults = struct([]); end
        if isfield(subj,'allEpochs'), FC.subjects(idx).allEpochs = subj.allEpochs; else, FC.subjects(idx).allEpochs = struct([]); end
        try, FC.subjects(idx).fcMeta = subj; catch, end
    end
end
FC.nSubjects = idx;
FC.loaded = idx > 0;
end

function R = computeFCStatsFlexible(G, groupA, groupB)
if nargin < 2 || isempty(groupA), groupA = ''; end
if nargin < 3, groupB = ''; end
groups = G.groups(:);
u = fcUniqueStableV19(groups);
if isempty(u), error('No FC groups available.'); end
if isempty(groupA) || ~any(strcmpi(groups,groupA)), groupA = u{1}; end
idxA = strcmpi(groups,groupA);
idxB = false(size(idxA));
if ~isempty(groupB) && ~strcmpi(groupA,groupB) && any(strcmpi(groups,groupB))
    idxB = strcmpi(groups,groupB);
elseif numel(u) >= 2
    for ii = 1:numel(u)
        if ~strcmpi(u{ii},groupA)
            groupB = u{ii};
            idxB = strcmpi(groups,groupB);
            break;
        end
    end
else
    groupB = 'None';
end
singleGroup = ~any(idxB);
ZA = G.Zstack(:,:,idxA);
meanZA = fcNanMean3(ZA);
[nR,~,~] = size(G.Zstack);
if singleGroup
    meanZB = nan(nR,nR); diffZ = nan(nR,nR); pMat = nan(nR,nR); tMat = nan(nR,nR);
else
    ZB = G.Zstack(:,:,idxB);
    meanZB = fcNanMean3(ZB);
    diffZ = meanZA - meanZB;
    pMat = nan(nR,nR); tMat = nan(nR,nR);
    for r = 1:nR
        for c = 1:nR
            a = squeeze(ZA(r,c,:)); b = squeeze(ZB(r,c,:));
            a = a(isfinite(a)); b = b(isfinite(b));
            if numel(a) >= 2 && numel(b) >= 2
                [t,p,~] = welchT_vec(a,b);
                tMat(r,c) = t; pMat(r,c) = p;
            end
        end
    end
end
R = struct();
R.mode = 'Functional Connectivity'; R.singleGroup = singleGroup;
R.groupA = groupA; R.groupB = groupB; R.nA = sum(idxA); R.nB = sum(idxB);
R.labels = G.labels; R.names = G.names;
R.meanZA = meanZA; R.meanZB = meanZB; R.meanRA = tanh(meanZA); R.meanRB = tanh(meanZB);
R.diffZ = diffZ; R.diffR = tanh(meanZA) - tanh(meanZB);
R.pMat = pMat; R.tMat = tMat;
R.subjectNames = G.subjectNames; R.groups = G.groups; R.sourceFiles = G.sourceFiles;
try, R.conditions = G.conditions; catch, R.conditions = {}; end
try, R.rowIndex = G.rowIndex; catch, R.rowIndex = []; end
end

function fcPlotFCAdvancedOneViewV15(ax,FC,R,reg1,reg2,viewMode,activeGroup,hemiMode,dispMode,thr,C)
if nargin < 11 || isempty(C), C = fcDefaultColorsV19(); end
if nargin < 10 || isempty(thr), thr = 0; end
if nargin < 9 || isempty(dispMode), dispMode = 'Pearson r'; end
if nargin < 8 || isempty(hemiMode), hemiMode = 'All / merged'; end
if nargin < 7 || isempty(activeGroup), activeGroup = R.groupA; end
cla(ax);
set(ax,'Visible','on','Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',11);
[M,climVal,titleText,ok,msg] = fcMatrixForGroupV19(R,activeGroup,dispMode);
if ~ok, fcTextV19(ax,msg,C); return; end
if nargin >= 6 && contains(lower(strtrimSafe(viewMode)),'seed')
    seedIdx = fcRegionIndexV19(R,reg1); v = M(seedIdx,:); v(seedIdx)=NaN;
    if thr > 0, v(abs(v)<thr)=NaN; end
    [~,ord] = sort(abs(v),'descend'); ord = ord(isfinite(v(ord))); ord = ord(1:min(35,numel(ord)));
    if isempty(ord), fcTextV19(ax,'No seed connections pass threshold.',C); return; end
    vals = v(ord); labs = fcAbbrevNames(R.names(ord),30);
    barh(ax,flipud(vals(:))); set(ax,'YTick',1:numel(vals),'YTickLabel',flipud(labs(:))); grid(ax,'on');
    title(ax,sprintf('Seed profile: %g | %s | %s',R.labels(seedIdx),R.names{seedIdx},titleText),'Color',C.txt,'Interpreter','none');
elseif nargin >= 6 && contains(lower(strtrimSafe(viewMode)),'pair')
    i1 = fcRegionIndexV19(R,reg1); i2 = fcRegionIndexV19(R,reg2);
    fcTextV19(ax,sprintf('Pair correlation\n\nROI 1: %g | %s\nROI 2: %g | %s\n\n%s\nValue: %.4f',R.labels(i1),R.names{i1},R.labels(i2),R.names{i2},titleText,M(i1,i2)),C);
else
    if thr > 0, M(abs(M)<thr)=0; end
    imagesc(ax,M); axis(ax,'image'); colormap(ax,fcBlueWhiteRed(256)); caxis(ax,climVal);
    cb = colorbar(ax); try, cb.Color = C.txt; catch, end
    title(ax,titleText,'Color',C.txt,'Interpreter','none','FontSize',15,'FontWeight','bold');
    tickIdx = fcTickIdx(numel(R.names));
    set(ax,'XTick',tickIdx,'XTickLabel',fcAbbrevNames(R.names(tickIdx),14),'YTick',tickIdx,'YTickLabel',fcAbbrevNames(R.names(tickIdx),14));
    try, xtickangle(ax,90); catch, end
end
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted);
end

function [M,climVal,titleText,ok,msg] = fcMatrixForGroupV19(R,activeGroup,dispMode)
ok = true; msg = '';
useZ = strcmpi(strtrimSafe(dispMode),'Fisher z');
isDiff = contains(lower(strtrimSafe(activeGroup)),'diff');
if isDiff
    if isfield(R,'singleGroup') && R.singleGroup, ok=false; msg='Difference unavailable in single-group mode.'; M=[]; climVal=[]; titleText=''; return; end
    if useZ, M=R.diffZ; else, M=R.diffR; end
    climVal = [-1 1]; titleText = [R.groupA ' - ' R.groupB];
elseif strcmpi(strtrimSafe(activeGroup),strtrimSafe(R.groupB))
    if isfield(R,'singleGroup') && R.singleGroup, ok=false; msg='Group B unavailable in single-group mode.'; M=[]; climVal=[]; titleText=''; return; end
    if useZ, M=R.meanZB; climVal=[-2.5 2.5]; else, M=R.meanRB; climVal=[-1 1]; end
    titleText = [R.groupB ' mean FC'];
else
    if useZ, M=R.meanZA; climVal=[-2.5 2.5]; else, M=R.meanRA; climVal=[-1 1]; end
    titleText = [R.groupA ' mean FC'];
end
end

function idx = fcRegionIndexV19(R,regionText)
idx = 1; regionText = strtrimSafe(regionText);
if isempty(regionText), return; end
tok = regexp(regionText,'^\s*([+-]?\d+\.?\d*)','tokens','once');
if ~isempty(tok), lab = str2double(tok{1}); else, lab = str2double(regionText); end
if isfinite(lab)
    hit = find(double(R.labels)==lab,1,'first'); if ~isempty(hit), idx = hit; return; end
end
s = lower(regexprep(regionText,'^\s*[+-]?\d+\.?\d*\s*\|\s*',''));
for ii = 1:numel(R.names)
    if contains(lower(strtrimSafe(R.names{ii})),s), idx = ii; return; end
end
end

function exportGroupFCResults(varargin)
S=[]; if nargin>=1 && isstruct(varargin{1}), S=varargin{1}; end
if isempty(S) || ~isstruct(S), error('Missing GroupAnalysis state struct for FC export.'); end
if ~isfield(S,'lastFC') || isempty(fieldnames(S.lastFC)), error('Compute FC first.'); end
R=S.lastFC; names=R.names;
outDir=uigetdir(pwd,'Select folder for FC export'); if isequal(outDir,0), return; end
tag=datestr(now,'yyyymmdd_HHMMSS'); outRoot=fullfile(outDir,['FC_GroupAnalysis_' sanitizeFilename([R.groupA '_vs_' R.groupB]) '_' tag]);
if exist(outRoot,'dir')~=7, mkdir(outRoot); end
try, writeFCMatrixCSV(fullfile(outRoot,'meanRA_PearsonR_GroupA.csv'),R.meanRA,names); catch ME, warning(ME.message); end
try, writeFCMatrixCSV(fullfile(outRoot,'meanRB_PearsonR_GroupB.csv'),R.meanRB,names); catch ME, warning(ME.message); end
try, writeFCMatrixCSV(fullfile(outRoot,'diffR_GroupA_minus_GroupB.csv'),R.diffR,names); catch ME, warning(ME.message); end
try, writeFCMatrixCSV(fullfile(outRoot,'p_values.csv'),R.pMat,names); catch ME, warning(ME.message); end
FC=struct(); try, FC=S.FC; catch, end
try, save(fullfile(outRoot,'FC_GroupAnalysis_Results.mat'),'R','FC','names','-v7.3'); catch ME, warning(ME.message); end
msgbox(sprintf('FC export complete:\n\n%s',outRoot),'FC export'); fprintf('\n[FC export] Saved:\n%s\n',outRoot);
end

function s = fcGetFieldCharCompatV19(S,fieldName,fb)
s = fb;
try
    if isstruct(S) && isfield(S,fieldName) && ~isempty(S.(fieldName))
        x = S.(fieldName);
        if ischar(x), s = strtrim(x); elseif isnumeric(x) || islogical(x), s = mat2str(x); elseif iscell(x) && ~isempty(x), s = strtrim(char(x{1})); else, s = strtrim(char(x)); end
    end
catch, s = fb; end
end

function v = fcGetFieldNumCompatV19(S,fieldName,fb)
v = fb;
try
    if isstruct(S) && isfield(S,fieldName) && ~isempty(S.(fieldName))
        x = S.(fieldName);
        if isnumeric(x) || islogical(x), x = double(x); v = x(1); elseif ischar(x), tmp = str2double(strtrim(x)); if isfinite(tmp), v = tmp; end; end
    end
catch, v = fb; end
end

function u = fcUniqueStableV19(c)
u = {};
for ii=1:numel(c)
    s = strtrimSafe(c{ii}); if isempty(s), s = 'Unassigned'; end
    if ~any(strcmpi(u,s)), u{end+1,1}=s; end %#ok<AGROW>
end
end

function C = fcDefaultColorsV19()
C=struct(); C.bg=[0.04 0.04 0.04]; C.axisBg=[0.02 0.02 0.02]; C.txt=[1 1 1]; C.muted=[0.75 0.75 0.75];
end

function fcTextV19(ax,msg,C)
cla(ax); axis(ax,'off'); set(ax,'Color',C.axisBg);
text(ax,0.5,0.5,msg,'Units','normalized','HorizontalAlignment','center','VerticalAlignment','middle','Color',C.txt,'FontSize',13,'Interpreter','none');
end






function s = strtrimSafe(x)
% Local safe string conversion helper for GroupAnalysis_FC.
% Needed because GroupAnalysis_FC.m cannot see local helpers from GroupAnalysis.m.
s = '';
try
    if nargin < 1 || isempty(x)
        return;
    end
    if ischar(x)
        s = strtrim(x);
    elseif iscell(x)
        if isempty(x)
            s = '';
        else
            s = strtrimSafe(x{1});
        end
    elseif isnumeric(x) || islogical(x)
        if isscalar(x)
            s = strtrim(num2str(x));
        else
            s = strtrim(mat2str(x));
        end
    else
        try
            s = strtrim(char(x));
        catch
            try
                s = strtrim(evalc('disp(x)'));
            catch
                s = '';
            end
        end
    end
catch
    s = '';
end
end

