
% GA_FISHERZ_STATS_PATCH_20260512
% FC group matrices are averaged/statistically compared in Fisher z space.
% Convert back with tanh(Z) only for Pearson-r display if needed.
function varargout = GroupAnalysis_FC(action, varargin)
% FC_DIRECT_LOAD_DISPATCH_V27
% Directly intercept FC bundle loading before any older dispatcher logic.
try
    if nargin >= 1
        actionKeyV27 = lower(regexprep(strtrim(char(action)),'[^a-zA-Z0-9]',''));
        if any(strcmp(actionKeyV27,{'loadfcgroupbundlesfromfiles','loadfcgroupbundlefromfiles','loadfcfiles','loadfcgroupbundles'}))
            if nargout == 0
                loadFCGroupBundlesFromFiles(varargin{:});
            else
                [varargout{1:nargout}] = loadFCGroupBundlesFromFiles(varargin{:});
            end
            return;
        end
    end
catch ME_fc_direct_v27
    rethrow(ME_fc_direct_v27);
end
% END_FC_DIRECT_LOAD_DISPATCH_V27


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





function [FC, cache] = loadFCGroupBundlesFromFiles(fileList, cache)
% Restored FC group-bundle loader V27.

if nargin < 2 || isempty(cache)
    cache = struct();
end
if nargin < 1 || isempty(fileList)
    fileList = {};
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
            try
                Ztmp(1:size(Ztmp,1)+1:end) = 0;
            catch
            end
            FC.subjects(idx).Z = Ztmp;
        end

        FC.subjects(idx).isStepMotor3D = false;
        try, FC.subjects(idx).isStepMotor3D = isfield(subj,'isStepMotor3D') && logical(subj.isStepMotor3D); catch, end

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

if FC.nSubjects < 1
    error('No valid FC subjects found in selected FC group bundle file(s).');
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
elseif isfield(L,'FC') && isstruct(L.FC)
    B = L.FC;
elseif isfield(L,'subjects')
    B = struct('subjects',L.subjects);
else
    error('File does not contain fcBundle/FC/subjects: %s', fp);
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

function key = makeCacheKey(varargin)
parts = cell(size(varargin));
for ii = 1:numel(varargin)
    parts{ii} = strtrimSafe(varargin{ii});
end
try
    key = strjoin(parts,'||');
catch
    key = parts{1};
    for ii = 2:numel(parts)
        key = [key '||' parts{ii}]; %#ok<AGROW>
    end
end
end

function s = strtrimSafe(x)
try
    if isempty(x)
        s = '';
    elseif ischar(x)
        s = strtrim(x);
    elseif iscell(x)
        if isempty(x), s = ''; else, s = strtrimSafe(x{1}); end
    elseif isnumeric(x) || islogical(x)
        if isscalar(x), s = strtrim(num2str(x)); else, s = strtrim(mat2str(x)); end
    else
        s = strtrim(char(x));
    end
catch
    s = '';
end
end

function g = inferFCGroupFromText(txt0)
g = 'Unassigned';
u = upper(strtrimSafe(txt0));
if isempty(u), return; end

if ~isempty(strfind(u,'PACAP')) || ~isempty(strfind(u,'GROUPA')) || ~isempty(strfind(u,'CONDA'))
    g = 'PACAP';
elseif ~isempty(strfind(u,'VEHICLE')) || ~isempty(strfind(u,'VEH')) || ~isempty(strfind(u,'CONTROL')) || ~isempty(strfind(u,'GROUPB')) || ~isempty(strfind(u,'CONDB')) || ~isempty(strfind(u,'PBS')) || ~isempty(strfind(u,'ACSF'))
    g = 'Vehicle';
end
end

function names = makeDefaultFCNames(labels)
labels = double(labels(:));
names = cell(numel(labels),1);
for ii = 1:numel(labels)
    names{ii,1} = sprintf('ROI_%g',labels(ii));
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
    if any(strcmp(vars,'fcBundle')) || any(strcmp(vars,'FC')) || any(strcmp(vars,'subjects'))
        tf = true;
        return;
    end
catch
end

try
    [~,nm,ext] = fileparts(fp);
    if strcmpi(ext,'.mat') && ~isempty(regexpi(nm,'FC|GroupBundle|connect','once'))
        tf = true;
    end
catch
end
end






function R = computeGroupFCStats(G, groupA, groupB)
% Robust FC group statistics V29.
if nargin < 2, groupA = ''; end
if nargin < 3, groupB = ''; end

if ~isstruct(G) || ~isfield(G,'Zstack') || isempty(G.Zstack)
    if isstruct(G) && isfield(G,'Rstack') && ~isempty(G.Rstack)
        Rtmp = max(-0.999999,min(0.999999,double(G.Rstack)));
        G.Zstack = atanh(Rtmp);
    else
        error('FC compute error: missing G.Zstack/Rstack.');
    end
end

nSub = size(G.Zstack,3);
nR = size(G.Zstack,1);

if ~isfield(G,'labels') || isempty(G.labels)
    G.labels = (1:nR)';
end
if ~isfield(G,'names') || isempty(G.names)
    G.names = cell(numel(G.labels),1);
    for ii = 1:numel(G.labels)
        G.names{ii,1} = sprintf('ROI_%g',G.labels(ii));
    end
end
if ~isfield(G,'groups') || isempty(G.groups)
    G.groups = repmat({'Unassigned'},nSub,1);
end

groups = fcV29_cellstr(G.groups);
for ii = 1:numel(groups)
    if isempty(groups{ii}), groups{ii} = 'Unassigned'; end
end
u = fcV29_uniqueStable(groups);
if isempty(u), u = {'Unassigned'}; end

groupA = fcV29_str(groupA);
groupB = fcV29_str(groupB);

if isempty(groupA) || strcmpi(groupA,'Group A') || ~any(strcmpi(groups,groupA))
    groupA = u{1};
end
idxA = strcmpi(groups,groupA);

if isempty(groupB) || strcmpi(groupB,'Group B') || strcmpi(groupB,groupA) || ~any(strcmpi(groups,groupB))
    groupB = 'None';
    for ii = 1:numel(u)
        if ~strcmpi(u{ii},groupA)
            groupB = u{ii};
            break;
        end
    end
end
idxB = strcmpi(groups,groupB);
singleGroup = ~any(idxB);

if ~any(idxA)
    error('No FC subjects found for Group A: %s', groupA);
end

ZA = double(G.Zstack(:,:,idxA));
meanZA = fcV29_nanmean3(ZA);

if singleGroup
    meanZB = nan(nR,nR);
    diffZ = nan(nR,nR);
    pMat = nan(nR,nR);
    tMat = nan(nR,nR);
else
    ZB = double(G.Zstack(:,:,idxB));
    meanZB = fcV29_nanmean3(ZB);
    diffZ = meanZA - meanZB;
    pMat = nan(nR,nR);
    tMat = nan(nR,nR);
    for r = 1:nR
        for c = 1:nR
            a = squeeze(ZA(r,c,:));
            b = squeeze(ZB(r,c,:));
            a = a(isfinite(a));
            b = b(isfinite(b));
            if numel(a) >= 2 && numel(b) >= 2
                [t,p] = fcV29_welch(a,b);
                tMat(r,c) = t;
                pMat(r,c) = p;
            end
        end
    end
end

R = struct();
R.mode = 'Functional Connectivity';
R.singleGroup = singleGroup;
R.groupA = groupA;
R.groupB = groupB;
R.nA = sum(idxA);
R.nB = sum(idxB);
R.labels = double(G.labels(:));
R.names = G.names(:);
R.meanZA = meanZA;
R.meanZB = meanZB;
R.meanRA = tanh(meanZA);
R.meanRB = tanh(meanZB);
R.diffZ = diffZ;
R.diffR = tanh(meanZA) - tanh(meanZB);
R.pMat = pMat;
R.tMat = tMat;
if isfield(G,'subjectNames'), R.subjectNames = G.subjectNames; else, R.subjectNames = cell(nSub,1); end
if isfield(G,'sourceFiles'), R.sourceFiles = G.sourceFiles; else, R.sourceFiles = cell(nSub,1); end
R.groups = groups;
if isfield(G,'conditions'), R.conditions = G.conditions; else, R.conditions = {}; end
if isfield(G,'rowIndex'), R.rowIndex = G.rowIndex; else, R.rowIndex = []; end
if singleGroup
    R.note = sprintf('Single-group FC summary only. Group A=%s, n=%d.',R.groupA,R.nA);
else
    R.note = sprintf('Two-group FC statistics. A=%s n=%d, B=%s n=%d.',R.groupA,R.nA,R.groupB,R.nB);
end
end

function R = computeFCStatsFlexible(G, groupA, groupB)
if nargin < 2, groupA = ''; end
if nargin < 3, groupB = ''; end
R = computeGroupFCStats(G,groupA,groupB);
end

function fcPlotFCAdvancedOneViewV15(ax,FC,R,reg1,reg2,viewMode,activeGroup,hemiMode,dispMode,thr,C)
if nargin < 11 || isempty(C), C = fcDefaultColorsV15(); end
if nargin < 10 || isempty(thr), thr = 0; end
if nargin < 9 || isempty(dispMode), dispMode = 'Pearson r'; end
if nargin < 8 || isempty(hemiMode), hemiMode = 'All / merged'; end
if nargin < 7 || isempty(activeGroup), activeGroup = 'Group A'; end
if nargin < 6 || isempty(viewMode), viewMode = 'Matrix summary'; end

try, cla(ax); catch, end
try, set(ax,'Visible','on','Color',C.axisBg,'XColor',C.muted,'YColor',C.muted); catch, end

v = lower(fcV29_str(viewMode));
try
    if ~isempty(strfind(v,'seed'))
        fcV29_plotSeed(ax,R,reg1,activeGroup,hemiMode,dispMode,thr,C);
    elseif ~isempty(strfind(v,'pair'))
        fcV29_plotPair(ax,R,reg1,reg2,activeGroup,dispMode,C);
    elseif ~isempty(strfind(v,'max'))
        fcV29_plotMax(ax,R,activeGroup,hemiMode,dispMode,thr,C);
    elseif ~isempty(strfind(v,'time'))
        fcV29_plotTime(ax,FC,R,reg1,activeGroup,C);
    elseif ~isempty(strfind(v,'heat'))
        fcV29_plotHeat(ax,FC,R,reg1,activeGroup,hemiMode,dispMode,thr,C);
    elseif ~isempty(strfind(v,'graph'))
        fcV29_plotGraph(ax,R,reg1,activeGroup,hemiMode,dispMode,thr,C);
    else
        fcV29_plotMatrix(ax,R,activeGroup,hemiMode,dispMode,thr,C);
    end
catch ME
    fcV29_text(ax,sprintf('FC display error:\n%s',ME.message),C);
end
end

function C = fcDefaultColorsV15()
C = struct();
C.bg = [0.04 0.04 0.04];
C.axisBg = [0.02 0.02 0.02];
C.txt = [1 1 1];
C.muted = [0.75 0.75 0.75];
end

function fcV29_plotMatrix(ax,R,activeGroup,hemiMode,dispMode,thr,C)
[M,namesX,namesY,~,titleText,climVal,ok,msg] = fcV29_getMatrix(R,activeGroup,dispMode,hemiMode);
if ~ok, fcV29_text(ax,msg,C); return; end
if thr > 0, M(abs(M) < thr) = 0; end
imagesc(ax,M);
colormap(ax,fcV29_cmap(256));
caxis(ax,climVal);
cb = colorbar(ax); try, cb.Color = C.txt; catch, end
axis(ax,'tight');
title(ax,[titleText ' | ' fcV29_str(hemiMode)],'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
ix = fcV29_tickIdx(numel(namesX));
iy = fcV29_tickIdx(numel(namesY));
set(ax,'XTick',ix,'XTickLabel',fcV29_abbrev(namesX(ix),14),'YTick',iy,'YTickLabel',fcV29_abbrev(namesY(iy),14));
try, xtickangle(ax,90); catch, end
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',9);
end

function fcV29_plotSeed(ax,R,reg1,activeGroup,hemiMode,dispMode,thr,C)
[M,namesX,~,~,titleText,~,ok,msg] = fcV29_getMatrix(R,activeGroup,dispMode,'All / merged');
if ~ok, fcV29_text(ax,msg,C); return; end
seedIdx = fcV29_regionIndex(R,reg1);
seedIdx = max(1,min(size(M,1),seedIdx));
v = M(seedIdx,:);
v(seedIdx) = NaN;
keep = true(numel(v),1);
h = lower(fcV29_str(hemiMode));
if ~isempty(strfind(h,'left')) && isempty(strfind(h,'left vs right')), keep = fcV29_hemiMask(namesX,'left'); end
if ~isempty(strfind(h,'right')), keep = fcV29_hemiMask(namesX,'right'); end
if ~any(keep), keep = true(numel(v),1); end
v(~transpose(keep(:))) = NaN;
if thr > 0, v(abs(v) < thr) = NaN; end
[~,ord] = sort(abs(v),'descend');
ord = ord(isfinite(v(ord)));
ord = ord(1:min(35,numel(ord)));
if isempty(ord), fcV29_text(ax,'No seed connections pass the current filter.',C); return; end
vals = v(ord);
labs = fcV29_abbrev(namesX(ord),32);
barh(ax,flipud(vals(:)));
set(ax,'YTick',1:numel(vals),'YTickLabel',flipud(labs(:)));
grid(ax,'on');
mx = max(abs(vals)); if ~isfinite(mx) || mx <= 0, mx = 1; end
xlim(ax,[-mx mx]);
title(ax,sprintf('Seed profile: %g | %s | %s',R.labels(seedIdx),R.names{seedIdx},titleText),'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
xlabel(ax,dispMode,'Color',C.muted);
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',9);
end

function fcV29_plotPair(ax,R,reg1,reg2,activeGroup,dispMode,C)
[M,~,~,~,titleText,~,ok,msg] = fcV29_getMatrix(R,activeGroup,dispMode,'All / merged');
if ~ok, fcV29_text(ax,msg,C); return; end
i1 = max(1,min(size(M,1),fcV29_regionIndex(R,reg1)));
i2 = max(1,min(size(M,2),fcV29_regionIndex(R,reg2)));
val = M(i1,i2);
s = sprintf('Pair correlation\n\nRegion 1: %g | %s\nRegion 2: %g | %s\n\n%s\nValue: %.4f',R.labels(i1),R.names{i1},R.labels(i2),R.names{i2},titleText,val);
fcV29_text(ax,s,C);
end

function fcV29_plotMax(ax,R,activeGroup,hemiMode,dispMode,thr,C)
[M,namesX,~,~,titleText,~,ok,msg] = fcV29_getMatrix(R,activeGroup,dispMode,hemiMode);
if ~ok, fcV29_text(ax,msg,C); return; end
n = min(size(M,1),size(M,2));
vals = []; labs = {};
for i = 1:n
    for j = i+1:n
        vv = M(i,j);
        if isfinite(vv) && abs(vv) >= thr
            vals(end+1,1) = vv;
            labs{end+1,1} = [fcV29_short(namesX{i},18) ' <-> ' fcV29_short(namesX{j},18)];
        end
    end
end
if isempty(vals), fcV29_text(ax,'No connections pass threshold.',C); return; end
[~,ord] = sort(abs(vals),'descend');
ord = ord(1:min(35,numel(ord)));
vals = vals(ord); labs = labs(ord);
barh(ax,flipud(vals(:)));
set(ax,'YTick',1:numel(vals),'YTickLabel',flipud(labs(:)));
grid(ax,'on');
title(ax,['Strongest connections | ' titleText],'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',8);
end

function fcV29_plotTime(ax,FC,R,reg1,activeGroup,C)
seedIdx = fcV29_regionIndex(R,reg1);
label = R.labels(seedIdx);
[T,~,ok,msg] = fcV29_collectTC(FC,label,activeGroup,R);
if ~ok, fcV29_text(ax,msg,C); return; end
plot(ax,T,'Color',[0.55 0.55 0.55]); hold(ax,'on');
m = nan(size(T,1),1);
for ii = 1:size(T,1)
    vv = T(ii,:); vv = vv(isfinite(vv));
    if ~isempty(vv), m(ii) = mean(vv); end
end
plot(ax,m,'LineWidth',3); hold(ax,'off');
grid(ax,'on');
title(ax,sprintf('ROI time course: %g | %s | %s',label,R.names{seedIdx},fcV29_resolveActiveGroup(R,activeGroup)),'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
xlabel(ax,'Frame stored in FC bundle'); ylabel(ax,'ROI signal');
try, legend(ax,{'individual subjects','group mean'},'TextColor',C.txt,'Color',C.axisBg,'Location','best'); catch, end
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',10);
end

function fcV29_plotHeat(ax,FC,R,reg1,activeGroup,hemiMode,dispMode,thr,C)
seedIdx = fcV29_regionIndex(R,reg1);
label = R.labels(seedIdx);
[H,subNames,namesUse,ok,msg] = fcV29_collectSubjectRows(FC,R,label,activeGroup,hemiMode,dispMode);
if ~ok, fcV29_text(ax,msg,C); return; end
if thr > 0, H(abs(H) < thr) = 0; end
imagesc(ax,H);
colormap(ax,fcV29_cmap(256));
if strcmpi(fcV29_str(dispMode),'Fisher z'), caxis(ax,[-2.5 2.5]); else, caxis(ax,[-1 1]); end
cb = colorbar(ax); try, cb.Color = C.txt; catch, end
title(ax,sprintf('Subject heatmap: seed %g | %s',label,R.names{seedIdx}),'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
ix = fcV29_tickIdx(size(H,2));
set(ax,'XTick',ix,'XTickLabel',fcV29_abbrev(namesUse(ix),14),'YTick',1:numel(subNames),'YTickLabel',subNames);
try, xtickangle(ax,90); catch, end
set(ax,'Color',C.axisBg,'XColor',C.muted,'YColor',C.muted,'FontSize',8);
end

function fcV29_plotGraph(ax,R,reg1,activeGroup,hemiMode,dispMode,thr,C)
[M,namesX,~,~,titleText,~,ok,msg] = fcV29_getMatrix(R,activeGroup,dispMode,'All / merged');
if ~ok, fcV29_text(ax,msg,C); return; end
seedIdx = fcV29_regionIndex(R,reg1);
v = M(seedIdx,:); v(seedIdx) = NaN;
if thr > 0, v(abs(v) < thr) = NaN; end
[~,ord] = sort(abs(v),'descend');
ord = ord(isfinite(v(ord)));
ord = ord(1:min(20,numel(ord)));
if isempty(ord), fcV29_text(ax,'No graph edges pass filter.',C); return; end
nodeIdx = [seedIdx transpose(ord(:))];
nNodes = numel(nodeIdx);
theta = linspace(0,2*pi,nNodes+1); theta(end) = [];
x = cos(theta); y = sin(theta);
cla(ax); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off'); set(ax,'Color',C.axisBg);
for k = 2:nNodes
    j = nodeIdx(k); val = M(seedIdx,j);
    lw = 0.5 + 4*min(1,abs(val));
    if val >= 0, col = [1 0.35 0.15]; else, col = [0.25 0.55 1]; end
    plot(ax,[x(1) x(k)],[y(1) y(k)],'-','Color',col,'LineWidth',lw);
end
scatter(ax,x,y,120,'filled','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor',[0 0 0]);
for k = 1:nNodes
    text(ax,x(k)*1.15,y(k)*1.15,fcV29_short(namesX{nodeIdx(k)},16),'Color',C.txt,'FontSize',8,'Interpreter','none');
end
title(ax,['Region graph | ' titleText],'Color',C.txt,'Interpreter','none','FontSize',14,'FontWeight','bold');
hold(ax,'off');
end

function [M,namesX,namesY,labelsX,titleText,climVal,ok,msg] = fcV29_getMatrix(R,activeGroup,dispMode,hemiMode)
ok = true; msg = '';
activeReal = fcV29_resolveActiveGroup(R,activeGroup);
useZ = strcmpi(fcV29_str(dispMode),'Fisher z');
key = lower(fcV29_str(activeReal));
if ~isempty(strfind(key,'diff')) || ~isempty(strfind(key,'a-b'))
    if isfield(R,'singleGroup') && R.singleGroup
        ok = false; msg = 'Difference unavailable: current FC result is single-group only.'; M=[]; namesX={}; namesY={}; labelsX=[]; titleText=''; climVal=[]; return;
    end
    if useZ, M = R.diffZ; else, M = R.diffR; end
    climVal = [-1 1]; titleText = [R.groupA ' - ' R.groupB];
elseif strcmpi(activeReal,R.groupB) && ~(isfield(R,'singleGroup') && R.singleGroup)
    if useZ, M = R.meanZB; climVal = [-2.5 2.5]; else, M = R.meanRB; climVal = [-1 1]; end
    titleText = [R.groupB ' mean FC'];
else
    if useZ, M = R.meanZA; climVal = [-2.5 2.5]; else, M = R.meanRA; climVal = [-1 1]; end
    titleText = [R.groupA ' mean FC'];
end
names = R.names(:); labels = R.labels(:);
[M,namesX,namesY,labelsX,msgH] = fcV29_applyHemi(M,names,labels,hemiMode);
if isempty(M), ok = false; msg = msgH; end
end

function activeReal = fcV29_resolveActiveGroup(R,activeGroup)
s = fcV29_str(activeGroup);
if isempty(s) || strcmpi(s,'Group A')
    activeReal = R.groupA;
elseif strcmpi(s,'Group B')
    activeReal = R.groupB;
elseif ~isempty(strfind(lower(s),'diff'))
    activeReal = 'Difference A-B';
else
    activeReal = s;
end
end

function [Mf,namesX,namesY,labelsX,msg] = fcV29_applyHemi(M,names,labels,hemiMode)
msg = ''; Mf = M; namesX = names; namesY = names; labelsX = labels;
h = lower(fcV29_str(hemiMode));
if isempty(h) || ~isempty(strfind(h,'all')) || ~isempty(strfind(h,'merged')), return; end
L = fcV29_hemiMask(names,'left');
Rr = fcV29_hemiMask(names,'right');
if ~any(L) && ~any(Rr)
    msg = 'No left/right labels detected in ROI names. Showing all/merged matrix instead.';
    return;
end
if ~isempty(strfind(h,'left vs right'))
    if ~any(L) || ~any(Rr), Mf=[]; namesX={}; namesY={}; labelsX=[]; msg='Left-vs-right view requires both left and right ROI labels.'; return; end
    Mf = M(L,Rr); namesY = names(L); namesX = names(Rr); labelsX = labels(Rr);
elseif ~isempty(strfind(h,'left'))
    if ~any(L), Mf=[]; namesX={}; namesY={}; labelsX=[]; msg='No left ROI labels detected.'; return; end
    Mf = M(L,L); namesX = names(L); namesY = names(L); labelsX = labels(L);
elseif ~isempty(strfind(h,'right'))
    if ~any(Rr), Mf=[]; namesX={}; namesY={}; labelsX=[]; msg='No right ROI labels detected.'; return; end
    Mf = M(Rr,Rr); namesX = names(Rr); namesY = names(Rr); labelsX = labels(Rr);
end
end

function mask = fcV29_hemiMask(names,side)
mask = false(numel(names),1);
for ii = 1:numel(names)
    ss = lower(fcV29_str(names{ii}));
    if strcmpi(side,'left')
        mask(ii) = ~isempty(regexp(ss,'(^|[\s_\-\(\[])(l|left|lh)([\s_\-\)\]]|$)','once')) || ~isempty(strfind(ss,'_l_')) || ~isempty(strfind(ss,' left'));
    else
        mask(ii) = ~isempty(regexp(ss,'(^|[\s_\-\(\[])(r|right|rh)([\s_\-\)\]]|$)','once')) || ~isempty(strfind(ss,'_r_')) || ~isempty(strfind(ss,' right'));
    end
end
end

function idx = fcV29_regionIndex(R,regionText)
idx = 1; ss = fcV29_str(regionText);
if isempty(ss), return; end
tok = regexp(ss,'^\s*([+-]?\d+\.?\d*)','tokens','once');
if ~isempty(tok), lab = str2double(tok{1}); else, lab = str2double(ss); end
if isfinite(lab)
    hit = find(double(R.labels(:)) == lab,1,'first');
    if ~isempty(hit), idx = hit; return; end
end
s2 = lower(regexprep(ss,'^\s*[+-]?\d+\.?\d*\s*\|\s*',''));
for ii = 1:numel(R.names)
    if ~isempty(strfind(lower(fcV29_str(R.names{ii})),s2)), idx = ii; return; end
end
end

function [T,subNames,ok,msg] = fcV29_collectTC(FC,label,activeGroup,R)
T = []; subNames = {}; ok = false; msg = 'No ROI time courses found in the FC bundle.';
if ~isstruct(FC) || ~isfield(FC,'subjects') || isempty(FC.subjects), return; end
g = fcV29_resolveActiveGroup(R,activeGroup);
for ii = 1:numel(FC.subjects)
    subj = FC.subjects(ii);
    if isfield(subj,'group') && ~strcmpi(fcV29_str(subj.group),g), continue; end
    [X,labs] = fcV29_getTCMatrix(subj);
    if isempty(X) || isempty(labs), continue; end
    hit = find(double(labs(:)) == double(label),1,'first');
    if isempty(hit), continue; end
    if size(X,2) == numel(labs), tc = X(:,hit); elseif size(X,1) == numel(labs), tc = transpose(X(hit,:)); else, continue; end
    if isempty(T), T = double(tc(:)); elseif numel(tc) == size(T,1), T(:,end+1) = double(tc(:)); end
    if isfield(subj,'name'), subNames{end+1,1} = fcV29_str(subj.name); else, subNames{end+1,1} = sprintf('Subject_%02d',ii); end
end
ok = ~isempty(T); if ok, msg = ''; end
end

function [X,labs] = fcV29_getTCMatrix(subj)
X = []; labs = [];
try, labs = double(subj.labels(:)); catch, labs = []; end
fields = {'meanTS','roiTS','timeCourses','roiTimeCourses','TS','tc'};
for ii = 1:numel(fields)
    f = fields{ii};
    try
        if isfield(subj,f) && ~isempty(subj.(f)) && isnumeric(subj.(f)), X = double(subj.(f)); return; end
    catch
    end
end
end

function [H,subNames,namesUse,ok,msg] = fcV29_collectSubjectRows(FC,R,label,activeGroup,hemiMode,dispMode)
H = []; subNames = {}; namesUse = R.names; ok = false; msg = 'No subject FC matrices found for heatmap.';
if ~isstruct(FC) || ~isfield(FC,'subjects') || isempty(FC.subjects), return; end
g = fcV29_resolveActiveGroup(R,activeGroup);
keep = true(numel(R.labels),1);
h = lower(fcV29_str(hemiMode));
if ~isempty(strfind(h,'left')) && isempty(strfind(h,'left vs right')), keep = fcV29_hemiMask(R.names,'left'); end
if ~isempty(strfind(h,'right')), keep = fcV29_hemiMask(R.names,'right'); end
if ~any(keep), keep = true(numel(R.labels),1); end
namesUse = R.names(keep);
for ii = 1:numel(FC.subjects)
    subj = FC.subjects(ii);
    if isfield(subj,'group') && ~strcmpi(fcV29_str(subj.group),g), continue; end
    try, labs = double(subj.labels(:)); catch, continue; end
    hit = find(labs == double(label),1,'first');
    if isempty(hit), continue; end
    if strcmpi(fcV29_str(dispMode),'Fisher z') && isfield(subj,'Z'), M = subj.Z; else, M = subj.R; end
    [~,idx] = ismember(double(R.labels(keep)),double(labs));
    if any(idx < 1), continue; end
    H(end+1,:) = double(M(hit,idx));
    if isfield(subj,'name'), subNames{end+1,1} = fcV29_str(subj.name); else, subNames{end+1,1} = sprintf('Subject_%02d',ii); end
end
ok = ~isempty(H); if ok, msg = ''; end
end

function c = fcV29_cellstr(x)
if isempty(x), c = {}; elseif iscell(x), c = x(:); elseif ischar(x), c = cellstr(x); else, try, c = cellstr(x); catch, c = {fcV29_str(x)}; end; end
for ii = 1:numel(c), c{ii} = fcV29_str(c{ii}); end
end

function u = fcV29_uniqueStable(c)
u = {};
for ii = 1:numel(c)
    ss = fcV29_str(c{ii}); if isempty(ss), ss = 'Unassigned'; end
    if ~any(strcmpi(u,ss)), u{end+1,1} = ss; end
end
end

function M = fcV29_nanmean3(X)
[n1,n2,~] = size(X); M = nan(n1,n2);
for r = 1:n1
    for c = 1:n2
        vv = squeeze(X(r,c,:)); vv = vv(isfinite(vv));
        if ~isempty(vv), M(r,c) = mean(vv); end
    end
end
end

function [t,p] = fcV29_welch(a,b)
a = a(:); b = b(:);
ma = mean(a); mb = mean(b); va = var(a); vb = var(b); na = numel(a); nb = numel(b);
se = sqrt(va/na + vb/nb);
if se <= 0 || ~isfinite(se), t = NaN; p = NaN; return; end
t = (ma - mb) / se;
df = (va/na + vb/nb)^2 / ((va/na)^2/(na-1) + (vb/nb)^2/(nb-1));
try, p = 2 * (1 - tcdf(abs(t),df)); catch, p = NaN; end
end

function fcV29_text(ax,msg,C)
cla(ax); axis(ax,'off'); try, set(ax,'Color',C.axisBg); catch, end
text(ax,0.5,0.5,msg,'Units','normalized','HorizontalAlignment','center','VerticalAlignment','middle','Color',C.txt,'FontSize',12,'Interpreter','none');
end

function cmap = fcV29_cmap(n)
if nargin < 1, n = 256; end
n = max(8,round(n));
half = floor(n/2);
b = [transpose(linspace(0,1,half)) transpose(linspace(0,1,half)) ones(half,1)];
r = [ones(n-half,1) transpose(linspace(1,0,n-half)) transpose(linspace(1,0,n-half))];
cmap = [b; r];
end

function idx = fcV29_tickIdx(n)
if n <= 12, idx = 1:n; else, idx = unique(round(linspace(1,n,12))); end
end

function out = fcV29_abbrev(names,maxLen)
if nargin < 2, maxLen = 14; end
out = cell(size(names));
for ii = 1:numel(names), out{ii} = fcV29_short(names{ii},maxLen); end
end

function ss = fcV29_short(ss,maxLen)
ss = fcV29_str(ss);
if nargin < 2, maxLen = 20; end
if numel(ss) > maxLen, ss = [ss(1:max(1,maxLen-3)) '...']; end
end

function ss = fcV29_str(x)
ss = '';
try
    if nargin < 1 || isempty(x), return;
    elseif ischar(x), ss = strtrim(x);
    elseif iscell(x), if ~isempty(x), ss = fcV29_str(x{1}); end
    elseif isnumeric(x) || islogical(x), if isscalar(x), ss = strtrim(num2str(x)); else, ss = strtrim(mat2str(x)); end
    else, try, ss = strtrim(char(x)); catch, ss = ''; end
    end
catch, ss = ''; end
end




function fcNoDataLocal(varargin)
% Robust fallback display helper for FC/GA views.
% Accepts: fcNoDataLocal(ax,msg,C), fcNoDataLocal(ax,msg), or fcNoDataLocal(msg).
ax = [];
msg = 'No data available for this view.';
C = struct();
C.axisBg = [0.02 0.02 0.02];
C.txt = [1 1 1];

try
    if nargin >= 1
        if isgraphics(varargin{1})
            ax = varargin{1};
            if nargin >= 2
                msg = fcNoDataLocal_str(varargin{2});
            end
            if nargin >= 3 && isstruct(varargin{3})
                C = varargin{3};
                if ~isfield(C,'axisBg'), C.axisBg = [0.02 0.02 0.02]; end
                if ~isfield(C,'txt'), C.txt = [1 1 1]; end
            end
        else
            msg = fcNoDataLocal_str(varargin{1});
        end
    end

    if isempty(ax) || ~isgraphics(ax)
        try
            ax = gca;
        catch
            return;
        end
    end

    try, cla(ax); catch, end
    try, axis(ax,'off'); catch, end
    try, set(ax,'Color',C.axisBg); catch, end

    text(ax,0.5,0.5,msg, ...
        'Units','normalized', ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', ...
        'Color',C.txt, ...
        'FontSize',12, ...
        'FontWeight','bold', ...
        'Interpreter','none');
catch
    % Never allow a no-data display helper to crash the GUI.
end
end

function s = fcNoDataLocal_str(x)
s = '';
try
    if nargin < 1 || isempty(x)
        s = '';
    elseif ischar(x)
        s = strtrim(x);
    elseif iscell(x)
        if ~isempty(x), s = fcNoDataLocal_str(x{1}); end
    elseif isnumeric(x) || islogical(x)
        if isscalar(x), s = strtrim(num2str(x)); else, s = strtrim(mat2str(x)); end
    else
        try, s = strtrim(char(x)); catch, s = ''; end
    end
catch
    s = '';
end
if isempty(s)
    s = 'No data available for this view.';
end
end

