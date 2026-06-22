
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



function groupName = inferFCGroupFromText(txt)
% Robust group inference for FC bundle loading.
% Used only when the FC bundle itself does not contain a group name.
groupName = 'Unassigned';
try
    txt = strtrimSafe(txt);
catch
    try
        txt = strtrim(char(txt));
    catch
        txt = '';
    end
end

t = lower(txt);

if isempty(t)
    return;
end

% Specific expected groups first.
if ~isempty(strfind(t,'vehicle')) || ~isempty(strfind(t,'veh'))
    groupName = 'Vehicle';
    return;
end

if ~isempty(strfind(t,'pacap'))
    groupName = 'PACAP';
    return;
end

if ~isempty(strfind(t,'control')) || ~isempty(strfind(t,'ctrl'))
    groupName = 'Control';
    return;
end

if ~isempty(strfind(t,'pbs')) || ~isempty(strfind(t,'saline')) || ~isempty(strfind(t,'acsf'))
    groupName = 'Vehicle';
    return;
end

% Generic fallback: try to use folder/file tokens if they look meaningful.
tok = regexp(txt,'[A-Za-z][A-Za-z0-9_\-]*','match');
bad = {'FC','GroupBundle','Group','Bundle','mat','results','Result','FunctionalConnectivity'};
for ii = numel(tok):-1:1
    candidate = tok{ii};
    if numel(candidate) < 2, continue; end
    if any(strcmpi(candidate,bad)), continue; end
    groupName = candidate;
    return;
end
end

function names = makeDefaultFCNames(labels)
% Default ROI names if the FC bundle has labels but no names.
try
    labels = double(labels(:));
catch
    labels = (1:numel(labels))';
end
names = cell(numel(labels),1);
for ii = 1:numel(labels)
    names{ii,1} = sprintf('ROI_%g', labels(ii));
end
end

function tf = isFCGroupBundleFile(fp)
% Robust check for FC group-bundle MAT files.
tf = false;
try
    if isempty(fp) || exist(fp,'file') ~= 2
        return;
    end
    [~,name,ext] = fileparts(fp);
    if ~strcmpi(ext,'.mat')
        return;
    end
    n = lower(name);
    if ~isempty(strfind(n,'fc')) || ~isempty(strfind(n,'connect')) || ~isempty(strfind(n,'groupbundle'))
        tf = true;
        return;
    end
    % If the name is not informative, inspect variables lightly.
    W = whos('-file',fp);
    vars = lower(strjoin({W.name},' '));
    if ~isempty(strfind(vars,'subjects')) || ~isempty(strfind(vars,'fc'))
        tf = true;
    end
catch
    tf = false;
end
end

function c = fcEnsureCellstrV23(x)
% Small utility used by compatibility code if needed later.
if isempty(x)
    c = {};
elseif iscell(x)
    c = x(:);
elseif ischar(x)
    c = cellstr(x);
else
    try
        c = cellstr(string(x));
    catch
        c = {char(evalc('disp(x)'))};
    end
end
end

