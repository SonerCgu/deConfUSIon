function Transf = coreg_3d(studio, forcedAnatomyFile, startAutomatic)
if nargin < 3, startAutomatic=false; end
if nargin < 2
    forcedAnatomyFile = '';
end
% =========================================================
% fUSI Studio - Atlas Coregistration
%
% ASCII only
% MATLAB 2017b compatible
%
% Main behavior:
%   - Lets you select an anatomy/anatomical reference file
%     (for example your BrainOnly_*.mat with brainImage)
%   - Opens registration GUI
%   - Saves/loads Transformation.mat in:
%       AnalysedData/Registration/Transformation.mat
%   - Collects RAW + ANALYSED + Registration functional candidates
%     for preview/register dropdown in registration_ccf
% =========================================================

fprintf('\n--- fUSI Atlas Coregistration ---\n');

Transf = [];

%% ---------------------------------------------------------
% 0) CHECK
%% ---------------------------------------------------------
if nargin < 1 || isempty(studio) || ~isfield(studio,'isLoaded') || ~studio.isLoaded
    error('Load dataset first.');
end

if ~isfield(studio,'loadedPath') || isempty(studio.loadedPath) || ~exist(studio.loadedPath,'dir')
    error('studio.loadedPath is missing or invalid.');
end

rawFolder = studio.loadedPath;

oldDir = pwd;
cleanupDir = onCleanup(@() cd(oldDir)); %#ok<NASGU>
cd(rawFolder);

%% ---------------------------------------------------------
% 1) LOAD ATLAS
%% ---------------------------------------------------------
atlasFile = 'allen_brain_atlas.mat';

atlasPath = which(atlasFile);
if isempty(atlasPath)
    here = fileparts(mfilename('fullpath'));
    cand = fullfile(here, atlasFile);
    if exist(cand,'file')
        atlasPath = cand;
    end
end

if isempty(atlasPath) || ~exist(atlasPath,'file')
    error('allen_brain_atlas.mat not found on path or next to coreg.m.');
end

SAtlas = load(atlasPath,'atlas');
if ~isfield(SAtlas,'atlas')
    error('Loaded allen_brain_atlas.mat but variable "atlas" is missing.');
end
atlas = SAtlas.atlas;

% deConfUSIon JM atlas auto-prepare START
try
    rootDCU = fileparts(mfilename('fullpath'));
    atlasToolsDCU = fullfile(rootDCU,'atlas_tools');
    if exist(atlasToolsDCU,'dir') == 7, addpath(atlasToolsDCU,'-begin'); end
    atlas = deConfUSIon_prepare_atlas(atlas, atlasPath);
catch ME_atlas
    warning('deConfUSIon:AtlasAutoPrepare', 'JM atlas auto-prepare skipped: %s', ME_atlas.message);
end
% deConfUSIon JM atlas auto-prepare END


%% ---------------------------------------------------------
% 2) ANALYSED + REGISTRATION FOLDER
%% ---------------------------------------------------------
analysedFolder = '';

if isfield(studio,'exportPath') && ~isempty(studio.exportPath) && exist(studio.exportPath,'dir')
    analysedFolder = studio.exportPath;
end

if isempty(analysedFolder)
    analysedFolder = inferAnalysedFromRaw(rawFolder);
end

if isempty(analysedFolder)
    warning('Could not infer AnalysedData folder. Falling back to RAW folder for Registration.');
    analysedFolder = rawFolder;
end

registrationDir = fullfile(analysedFolder,'Registration');
if ~exist(registrationDir,'dir')
    mkdir(registrationDir);
end

fprintf('RAW folder         : %s\n', rawFolder);
fprintf('ANALYSED folder    : %s\n', analysedFolder);
fprintf('Registration folder: %s\n', registrationDir);

%% ---------------------------------------------------------
% 3) SEARCH FOLDERS FOR ANATOMY SELECTION
%% ---------------------------------------------------------
searchFolders = { ...
    rawFolder, ...
    fullfile(rawFolder,'Visualization'), ...
    fullfile(rawFolder,'visualization'), ...
    fullfile(rawFolder,'Visualisation'), ...
    fullfile(rawFolder,'Mask'), ...
    fullfile(rawFolder,'Masks'), ...
    analysedFolder, ...
    fullfile(analysedFolder,'Visualization'), ...
    fullfile(analysedFolder,'visualization'), ...
    fullfile(analysedFolder,'Visualisation'), ...
    fullfile(analysedFolder,'Mask'), ...
    fullfile(analysedFolder,'Masks'), ...
    registrationDir ...
    };

searchFolders = searchFolders(~cellfun(@isempty, searchFolders));
searchFolders = searchFolders(cellfun(@(p) exist(p,'dir')==7, searchFolders));
searchFolders = unique(searchFolders,'stable');

%% ---------------------------------------------------------
% 4) SELECT ANATOMY SOURCE
%% ---------------------------------------------------------
useActive=strcmp(forcedAnatomyFile,'__active_volume__');
fileWasForced = useActive || (~isempty(forcedAnatomyFile) && exist(forcedAnatomyFile,'file') == 2);

if fileWasForced
    anatomyFile = forcedAnatomyFile;
    fprintf('Selected 3D anatomy source file:\n%s\n', anatomyFile);
else
    [fileList, displayList] = collectAnatomyFiles(searchFolders, rawFolder, analysedFolder, registrationDir);

    if isempty(fileList)
        error('No anatomy candidates found in RAW, ANALYSED, or Registration folders.');
    end

    [idx, tf] = listdlg( ...
        'PromptString','Select anatomical source (RAW/ANA/REG, MAT/NIfTI/image):', ...
        'SelectionMode','single', ...
        'ListString',displayList, ...
        'ListSize',[860 420]);

    if ~tf
        fprintf('Coregistration cancelled.\n');
        return;
    end

    anatomyFile = fileList{idx};
end

%% ---------------------------------------------------------
% 5) LOAD + DETECT ANATOMY VOLUME
%% ---------------------------------------------------------
anatomic = [];

if useActive
    active=studio.datasets.(studio.activeDataset);
    if ~isfield(active,'I') || ndims(active.I)~=4
        error('The active dataset must contain a loaded 3D time series.');
    end
    anatomic=struct('Data',mean(active.I,4,'omitnan'),'arrayOrder','DV-LR-AP');
    if isfield(active,'voxelSize'), anatomic.voxelSize=active.voxelSize; end
elseif endsWithLower(anatomyFile,'.mat')
    S = load(anatomyFile);
    [candNames, candStruct] = detectAnatomyCandidatesFromMat(S);

    if isempty(candStruct)
        error('Selected MAT contains no usable anatomy. No suitable struct.Data or numeric 2D/3D array was found.');
    end

    if numel(candStruct) > 1

        if fileWasForced
            % User already selected / forced the anatomy source upstream.
            % Do not show a second popup. Use the first prioritized real anatomy field.
            anatomic = candStruct{1};
            fprintf('Auto-selected anatomy field: %s\n', candNames{1});
        else
            pretty = candNames;
            for k = 1:numel(candStruct)
                try
                    sz = size(candStruct{k}.Data);
                    pretty{k} = sprintf('%s   [%s]', candNames{k}, joinDims(sz));
                catch
                end
            end

            [jdx, tf2] = listdlg( ...
                'PromptString','Multiple anatomy candidates found. Select one:', ...
                'SelectionMode','single', ...
                'ListString',pretty, ...
                'ListSize',[860 360]);

            if ~tf2
                fprintf('Coregistration cancelled.\n');
                return;
            end

            anatomic = candStruct{jdx};
        end

    else
        anatomic = candStruct{1};
    end

elseif endsWithLower(anatomyFile,'.nii') || endsWithLower(anatomyFile,'.nii.gz')
    [D, vox] = loadNiftiMaybeGz(anatomyFile);
    anatomic = struct();
    anatomic.Data = double(D);
    if isempty(vox)
        vox = [1 1 1];
    end
    anatomic.voxelSize = vox; % NIfTI spacings are displayed for confirmation below.

elseif isImageFile(anatomyFile)
    V = load2DImageAsVolume(anatomyFile);
    anatomic = struct();
    anatomic.Data = double(V);
    anatomic.VoxelSize = [1 1 1];

else
    error('Unsupported file type: %s', anatomyFile);
end

if ~isfield(anatomic,'Data') || isempty(anatomic.Data) || ~isnumeric(anatomic.Data)
    error('Selected anatomy does not contain valid numeric Data.');
end

if ndims(anatomic.Data) == 2
    anatomic.Data = reshape(anatomic.Data, size(anatomic.Data,1), size(anatomic.Data,2), 1);
end

if ~isfield(anatomic,'VoxelSize') || isempty(anatomic.VoxelSize)
    anatomic.VoxelSize = [1 1 1];
end

%% ---------------------------------------------------------
% 5b) SCAN GEOMETRY - units MUST match atlas.VoxelSize
%% ---------------------------------------------------------
% interpolate3D resamples with (n-1)*d/dAtlas. allen_brain_atlas.mat has
% VoxelSize = [50 50 50] (micrometres). A scan left at the default [1 1 1]
% is therefore shrunk 50x on every axis: a 90x64x54 volume collapses to
% about 2x3x2 voxels and is invisible in the GUI.
%
% interpolate3D also expects Data as [Z X Y] (dim 1 = slice axis), while
% deConfUSIon volumes are [Y X Z]. Both are corrected here.

if ndims(anatomic.Data)~=3 || min(size(anatomic.Data))<4
    error('Select a true 3D anatomical volume for 3D registration. Use coronal mode for 2D images.');
end
anatomic=AtlasRegistration('geometry',anatomic,atlas);
if isempty(anatomic), fprintf('Coregistration cancelled during geometry selection.\n'); return; end

fprintf('Anatomy source: %s\n', anatomyFile);
fprintf('Anatomy size  : %s\n', mat2str(size(anatomic.Data)));
fprintf('VoxelSize     : %s\n', mat2str(anatomic.VoxelSize));

%% ---------------------------------------------------------
% 6) FUNCTIONAL CANDIDATES FOR GUI DROPDOWN
%% ---------------------------------------------------------
funcRoots = {rawFolder, analysedFolder, registrationDir};
funcRoots = funcRoots(~cellfun(@isempty, funcRoots));
funcRoots = funcRoots(cellfun(@(p) exist(p,'dir')==7, funcRoots));
funcRoots = unique(funcRoots, 'stable');

[funcFiles, funcLabels] = collectFunctionalFilesRecursive(funcRoots, rawFolder, analysedFolder, registrationDir);

keep = true(size(funcFiles));
for k = 1:numel(funcFiles)
    keep(k) = ~strcmpi(funcFiles{k}, anatomyFile);
end
funcFiles = funcFiles(keep);
funcLabels = funcLabels(keep);

% ---- put the anatomy from THIS animal / THIS session first ------------
% The recursive sweep returns every MAT under RAW + ANALYSED + Registration.
% Rank by how well each path matches the loaded dataset folder and the
% anatomy file just selected, so the popup opens on the right one.
if ~isempty(funcFiles)
    [anatDir, anatStem] = fileparts(anatomyFile);
    loadStem = '';
    try
        if isfield(studio,'loadedPath') && ~isempty(studio.loadedPath)
            [~, loadStem] = fileparts(studio.loadedPath);
        end
    catch
    end

    score = zeros(1, numel(funcFiles));
    for fi = 1:numel(funcFiles)
        thisDir = fileparts(funcFiles{fi});
        if strcmpi(thisDir, anatDir),                          score(fi) = score(fi) + 4; end
        if ~isempty(loadStem) && ...
           ~isempty(strfind(lower(funcFiles{fi}), lower(loadStem)))    %#ok<STREMP>
            score(fi) = score(fi) + 3;
        end
        if ~isempty(anatStem) && ...
           ~isempty(strfind(lower(funcFiles{fi}), lower(anatStem)))    %#ok<STREMP>
            score(fi) = score(fi) + 2;
        end
        if ~isempty(strfind(lower(funcLabels{fi}), 'brainonly'))       %#ok<STREMP>
            score(fi) = score(fi) + 1;
        end
    end

    [~, ord]   = sort(score, 'descend');
    funcFiles  = funcFiles(ord);
    funcLabels = funcLabels(ord);

    if max(score) > 0
        fprintf('Functional candidate pre-selected: %s\n', funcLabels{1});
    end
end
funcCandidates = struct();
funcCandidates.files = funcFiles;
funcCandidates.labels = funcLabels;

fprintf('Functional candidates found: %d\n', numel(funcFiles));

%% ---------------------------------------------------------
% 7) OPTIONAL LOAD PREVIOUS TRANSFORMATION
%% ---------------------------------------------------------
usePrevious = false;
prevFile = fullfile(registrationDir,'Transformation.mat');

if exist(prevFile,'file')
    choice = questdlg( ...
        sprintf('Load previous Transformation.mat from:\n%s', registrationDir), ...
        'Previous Transformation', ...
        'Yes','No','No');

    if strcmp(choice,'Yes')
        tmp = load(prevFile,'Transf');
        if isfield(tmp,'Transf') && isstruct(tmp.Transf) && isfield(tmp.Transf,'M')
            usePrevious = true;
            Transf = tmp.Transf;
            if strcmp(anatomic.Geometry.convention,'coronal_stack_v2') && ...
                    (~isfield(Transf,'scanGeometry') || ~isfield(Transf.scanGeometry,'convention') || ...
                    ~strcmp(Transf.scanGeometry.convention,'coronal_stack_v2'))
                warning('deConfUSIon:OldAtlasOrientation','Previous transform used the old axis conversion. Starting a fresh coronal alignment; the old file is unchanged.');
                usePrevious=false; Transf=[];
            end
        else
            warning('Transformation.mat found but variable "Transf" is missing or invalid. Starting fresh.');
            usePrevious = false;
            Transf = [];
        end
    end
end

%% ---------------------------------------------------------
% 8) LAUNCH registration_ccf GUI
%% ---------------------------------------------------------
fprintf('Launching registration_ccf GUI...\n');

if usePrevious
    R = registration_ccf(atlas, anatomic, Transf, [], registrationDir, funcCandidates);
else
    R = registration_ccf(atlas, anatomic, [], [], registrationDir, funcCandidates);
end
set(R.H.figure1,'Name',sprintf('3D Atlas Registration | %s | MATLAB %d',studio.loadedName,feature('getpid')));
if startAutomatic, R.onAutoRegister(); end

try
    if isprop(R,'H') && isstruct(R.H) && isfield(R.H,'figure1') && isgraphics(R.H.figure1)
        waitfor(R.H.figure1);
    end
catch
end

%% ---------------------------------------------------------
% 9) RETURN TRANSFORMATION
%% ---------------------------------------------------------
if exist(prevFile,'file')
    tmp = load(prevFile,'Transf');
    if isfield(tmp,'Transf')
        Transf = tmp.Transf;
        logCoregMessage(studio, prevFile);
    else
        warning('Transformation.mat exists but does not contain Transf.');
        Transf = [];
    end
else
    warning('Transformation.mat not found after registration.');
    Transf = [];
end

fprintf('--- Coregistration finished ---\n');

end


%% =======================================================================
% Logging helper
%% =======================================================================
function logCoregMessage(studio, transfPath)

msg = sprintf('Saved Transformation.mat: %s', transfPath);
fprintf('[COREG] %s\n', msg);

try
    if isfield(studio,'addLog') && isa(studio.addLog,'function_handle')
        studio.addLog(msg);
        return;
    end
end

try
    if isfield(studio,'log') && isa(studio.log,'function_handle')
        studio.log(msg);
        return;
    end
end

try
    if isfield(studio,'logHandle') && isgraphics(studio.logHandle)
        old = get(studio.logHandle,'String');
        if ischar(old)
            old = {old};
        end
        ts = datestr(now,'HH:MM:SS');
        newLine = sprintf('[%s] %s', ts, msg);
        set(studio.logHandle,'String',[old; {newLine}]);
        drawnow limitrate nocallbacks;
    end
end

end


%% =======================================================================
% Anatomy file collection
%% =======================================================================
function [fileList, displayList] = collectAnatomyFiles(searchFolders, rawRoot, analysedRoot, registrationRoot)

fileList = {};
displayList = {};

for i = 1:numel(searchFolders)
    f = searchFolders{i};
    if isempty(f) || ~exist(f,'dir')
        continue;
    end

    d = dir(fullfile(f,'*.mat'));
    for k = 1:numel(d)
        fp = fullfile(f, d(k).name);

        if strcmpi(d(k).name,'Transformation.mat')
            continue;
        end
        if strcmpi(d(k).name,'allen_brain_atlas.mat')
            continue;
        end

        fileList{end+1} = fp; %#ok<AGROW>
        displayList{end+1} = makeDisplayName(fp, rawRoot, analysedRoot, registrationRoot); %#ok<AGROW>
    end

    d = dir(fullfile(f,'*.nii'));
    for k = 1:numel(d)
        fp = fullfile(f, d(k).name);
        fileList{end+1} = fp; %#ok<AGROW>
        displayList{end+1} = makeDisplayName(fp, rawRoot, analysedRoot, registrationRoot); %#ok<AGROW>
    end

    d = dir(fullfile(f,'*.nii.gz'));
    for k = 1:numel(d)
        fp = fullfile(f, d(k).name);
        fileList{end+1} = fp; %#ok<AGROW>
        displayList{end+1} = makeDisplayName(fp, rawRoot, analysedRoot, registrationRoot); %#ok<AGROW>
    end

    exts = {'*.png','*.jpg','*.jpeg','*.tif','*.tiff','*.bmp'};
    for e = 1:numel(exts)
        d = dir(fullfile(f, exts{e}));
        for k = 1:numel(d)
            fp = fullfile(f, d(k).name);
            fileList{end+1} = fp; %#ok<AGROW>
            displayList{end+1} = makeDisplayName(fp, rawRoot, analysedRoot, registrationRoot); %#ok<AGROW>
        end
    end
end

[displayList, ia] = unique(displayList, 'stable');
fileList = fileList(ia);

end


%% =======================================================================
% Functional dropdown collection
%% =======================================================================
function [fileList, displayList] = collectFunctionalFilesRecursive(rootFolders, rawRoot, analysedRoot, registrationRoot)

fileList = {};
displayList = {};

for i = 1:numel(rootFolders)
    rootDir = rootFolders{i};
    if isempty(rootDir) || ~exist(rootDir,'dir')
        continue;
    end

    filesHere = collectFilesRecursive(rootDir);

    for k = 1:numel(filesHere)
        fp = filesHere{k};

        if ~isAllowedFunctionalFile(fp)
            continue;
        end

        fileList{end+1} = fp; %#ok<AGROW>
        displayList{end+1} = makeDisplayName(fp, rawRoot, analysedRoot, registrationRoot); %#ok<AGROW>
    end
end

[displayList, ia] = unique(displayList, 'stable');
fileList = fileList(ia);

end


function files = collectFilesRecursive(rootDir)

files = {};

if isempty(rootDir) || ~exist(rootDir,'dir')
    return;
end

d = dir(rootDir);

for i = 1:numel(d)
    nm = d(i).name;

    if d(i).isdir
        if strcmp(nm,'.') || strcmp(nm,'..')
            continue;
        end

        subFiles = collectFilesRecursive(fullfile(rootDir, nm));
        if ~isempty(subFiles)
            files = [files subFiles]; %#ok<AGROW>
        end
    else
        fp = fullfile(rootDir, nm);
        files{end+1} = fp; %#ok<AGROW>
    end
end

end


function tf = isAllowedFunctionalFile(fp)

tf = false;

[~, nm, ext] = fileparts(fp);
fullLower = lower(fp);
nameLower = lower(nm);

if strcmpi([nm ext], 'Transformation.mat')
    return;
end
if strcmpi([nm ext], 'allen_brain_atlas.mat')
    return;
end

if ~isempty(strfind(fullLower, [filesep '.git' filesep])) %#ok<STREMP>
    return;
end

if strcmpi(ext,'.nii') || strcmpi(ext,'.gz')
    tf = true;
    return;
end

if strcmpi(ext,'.mat')
    if ~isempty(strfind(nameLower,'transform')) %#ok<STREMP>
        return;
    end
    tf = hasLikelyImageContent(fp);
end

end


function tf = hasLikelyImageContent(matFile)

tf = false;

try
    info = whos('-file', matFile);

    for i = 1:numel(info)
        c = info(i).class;
        sz = info(i).size;

        if strcmp(c,'double') || strcmp(c,'single') || strcmp(c,'uint16') || strcmp(c,'uint8') || strcmp(c,'logical')
            if numel(sz) >= 2 && numel(sz) <= 4 && prod(double(sz)) > 100
                tf = true;
                return;
            end
        end

        if strcmp(c,'struct')
            tf = true;
            return;
        end
    end
catch
    tf = false;
end

end


%% =======================================================================
% Display naming
%% =======================================================================
function s = makeDisplayName(fullpath, rawRoot, analysedRoot, registrationRoot)

try
    if ~isempty(registrationRoot) && strncmpi(fullpath, registrationRoot, numel(registrationRoot))
        rel = fullpath(numel(registrationRoot)+1:end);
        if ~isempty(rel) && rel(1)==filesep
            rel = rel(2:end);
        end
        s = ['REG: ' rel];
        return;
    end
catch
end

try
    if ~isempty(rawRoot) && strncmpi(fullpath, rawRoot, numel(rawRoot))
        rel = fullpath(numel(rawRoot)+1:end);
        if ~isempty(rel) && rel(1)==filesep
            rel = rel(2:end);
        end
        s = ['RAW: ' rel];
        return;
    end
catch
end

try
    if ~isempty(analysedRoot) && strncmpi(fullpath, analysedRoot, numel(analysedRoot))
        rel = fullpath(numel(analysedRoot)+1:end);
        if ~isempty(rel) && rel(1)==filesep
            rel = rel(2:end);
        end
        s = ['ANA: ' rel];
        return;
    end
catch
end

s = fullpath;
end


%% =======================================================================
% Path inference
%% =======================================================================
function out = inferAnalysedFromRaw(rawFolder)
out = '';
if isempty(rawFolder)
    return;
end

cand = strrep(rawFolder, [filesep 'RawData' filesep], [filesep 'AnalysedData' filesep]);
if ~strcmp(cand, rawFolder) && exist(cand,'dir')
    out = cand;
    return;
end

cand = strrep(rawFolder, [filesep 'rawdata' filesep], [filesep 'analyseddata' filesep]);
if ~strcmp(cand, rawFolder) && exist(cand,'dir')
    out = cand;
    return;
end
end


%% =======================================================================
% Data loading helpers
%% =======================================================================
function tf = endsWithLower(str, suffix)
str = lower(str);
suffix = lower(suffix);
if numel(str) < numel(suffix)
    tf = false;
    return;
end
tf = strcmp(str(end-numel(suffix)+1:end), suffix);
end


function [candNames, candStruct] = detectAnatomyCandidatesFromMat(S)

fields = fieldnames(S);
candNames = {};
candStruct = {};

voxHint = [];
try
    if isfield(S,'VoxelSize')
        voxHint = S.VoxelSize;
    end
    if isempty(voxHint) && isfield(S,'meta') && isstruct(S.meta) && isfield(S.meta,'VoxelSize')
        voxHint = S.meta.VoxelSize;
    end
catch
end
if isempty(voxHint)
    voxHint = [1 1 1];
end

preferred = { ...
    'brainImage', ...
    'anatomical_reference', ...
    'anatomical_reference_raw', ...
    'I', ...
    'Data', ...
    'brainMask', ...
    'mask' ...
    };

orderedFields = {};
for i = 1:numel(preferred)
    if isfield(S, preferred{i})
        orderedFields{end+1} = preferred{i}; %#ok<AGROW>
    end
end
for i = 1:numel(fields)
    if isempty(find(strcmp(orderedFields, fields{i}), 1))
        orderedFields{end+1} = fields{i}; %#ok<AGROW>
    end
end

for i = 1:numel(orderedFields)
    nm = orderedFields{i};
    v = S.(nm);

    if isstruct(v)
        subPref = {'Data','I','brainImage','anatomical_reference', ...
                   'anatomical_reference_raw','underlay','img','image'};
        for sIdx = 1:numel(subPref)
            if isfield(v, subPref{sIdx}) && ~isempty(v.(subPref{sIdx})) ...
                    && (isnumeric(v.(subPref{sIdx})) || islogical(v.(subPref{sIdx})))
                v.Data = v.(subPref{sIdx});
                break;
            end
        end
    end
    if isstruct(v) && isfield(v,'Data') && ~isempty(v.Data) && isnumeric(v.Data)
        tmp = v;
        tmp.Data = double(tmp.Data);
        if ~isfield(tmp,'VoxelSize') || isempty(tmp.VoxelSize)
            tmp.VoxelSize = voxHint;
        end
        if ndims(tmp.Data) == 2
            tmp.Data = reshape(tmp.Data, size(tmp.Data,1), size(tmp.Data,2), 1);
        end
if ndims(tmp.Data) == 4 && exist('deConfUSIon_collapse_time','file') == 2
    try
        [tmp.Data, ctNote] = deConfUSIon_collapse_time(tmp.Data);
        fprintf('[coreg] %s' , ctNote); fprintf(char(10));
    catch ME_ct
        warning('deConfUSIon:CollapseTime', '4D collapse failed: %s', ME_ct.message);
    end
end
        if ndims(tmp.Data) == 3
            candNames{end+1}  = nm; %#ok<AGROW>
            candStruct{end+1} = tmp; %#ok<AGROW>
        end
        continue;
    end

    if (isnumeric(v) || islogical(v)) && ~isempty(v)
        d = ndims(v);
        if d == 2 || d == 3
            tmp = struct();
            tmp.Data = double(v);
            if d == 2
                tmp.Data = reshape(tmp.Data, size(tmp.Data,1), size(tmp.Data,2), 1);
            end
            tmp.VoxelSize = voxHint;
            candNames{end+1}  = nm; %#ok<AGROW>
            candStruct{end+1} = tmp; %#ok<AGROW>
        end
    end
end
% ---- keep only real anatomy candidates -------------------------------
% A mask-editor MAT exposes ~15 fields (masks, flags, bundles). Only a few
% are usable anatomy. If any of those are present, hide the rest.
if ~isempty(candNames)
    anatomyPref = {'brainImage','anatomical_reference_raw','anatomical_reference', ...
                   'sliceUnderlayProcessed','sliceUnderlayRaw','I','Data'};
    keepIdx = [];
    for a = 1:numel(anatomyPref)
        for b = 1:numel(candNames)
            if strcmpi(candNames{b}, anatomyPref{a}) && ~any(keepIdx == b)
                keepIdx(end+1) = b; %#ok<AGROW>
            end
        end
    end
    if ~isempty(keepIdx)
        candNames  = candNames(keepIdx);
        candStruct = candStruct(keepIdx);
    end
end

end


function [D, vox] = loadNiftiMaybeGz(f)

vox = [];
isGz = (numel(f) >= 7 && strcmpi(f(end-6:end),'.nii.gz'));

if isGz
    tmpDir = tempname;
    mkdir(tmpDir);
    gunzip(f, tmpDir);
    d = dir(fullfile(tmpDir,'*.nii'));
    if isempty(d)
        error('Failed to gunzip: %s', f);
    end
    niiFile = fullfile(tmpDir, d(1).name);

    info = niftiinfo(niiFile);
    D = niftiread(info);

    try
        if isfield(info,'PixelDimensions') && numel(info.PixelDimensions) >= 3
            vox = double(info.PixelDimensions(1:3));
        end
    catch
    end

    try
        rmdir(tmpDir,'s');
    catch
    end
else
    info = niftiinfo(f);
    D = niftiread(info);
    try
        if isfield(info,'PixelDimensions') && numel(info.PixelDimensions) >= 3
            vox = double(info.PixelDimensions(1:3));
        end
    catch
    end
end
end


function tf = isImageFile(f)
f = lower(f);
tf = endsWithLower(f,'.png') || endsWithLower(f,'.jpg') || endsWithLower(f,'.jpeg') || ...
     endsWithLower(f,'.tif') || endsWithLower(f,'.tiff') || endsWithLower(f,'.bmp');
end


function V = load2DImageAsVolume(f)

I = imread(f);

if ndims(I) == 3
    I = double(I);
    I = (I(:,:,1) + I(:,:,2) + I(:,:,3)) / 3;
else
    I = double(I);
end

mn = min(I(:));
mx = max(I(:));
if mx > mn
    I = (I - mn) ./ (mx - mn);
end

V = reshape(I, size(I,1), size(I,2), 1);
end


function s = joinDims(sz)
if isempty(sz)
    s = '';
    return;
end
s = num2str(sz(1));
for k = 2:numel(sz)
    s = [s 'x' num2str(sz(k))]; %#ok<AGROW>
end
end
