function fusi_make_clean(target, varargin)
% FUSI_MAKE_CLEAN  Rewrite acquired files in the scanner GUI variable set.
%
% DRY RUN BY DEFAULT. Nothing is written or deleted until 'Apply', true.
%
% Background
%   The scanner GUI saves exactly three variables:
%       I, metadata, events
%   The acquisition script saved I and md, where md held the scanner
%   metadata plus ~40 extra acquisition fields. Loaders that scan the
%   variables pick md instead of metadata, misread the geometry, and show
%   64 slices instead of 54 with the wrong orientation.
%
%   This rewrites each file with ONLY I, metadata and events, so it is
%   indistinguishable from a GUI-saved file.
%
% What happens to each file
%   1. metadata is taken from the existing metadata variable, or rebuilt
%      from md if metadata is absent.
%   2. events is taken from the existing events, or from md.tag, or built
%      empty in the GUI format.
%   3. A temporary file is written and VERIFIED (variables present, md
%      absent, size(I) unchanged).
%   4. Only then is the original moved into a backup subfolder, or deleted
%      if 'DeleteOriginal' is true.
%   5. The verified temporary file takes the original filename.
%
%   The acquisition fields in md are preserved by default in a sidecar
%   file <name>_acqinfo.mat, so nothing is lost. Pass 'KeepAcqInfo', false
%   to skip that.
%
% Usage
%   fusi_make_clean('Z:\...\RGRO_260817_1024_MM_B6J_1336')            % preview
%   fusi_make_clean(folder, 'Apply', true)                            % rewrite
%   fusi_make_clean(folder, 'Apply', true, 'DeleteOriginal', true)    % no backup copy
%   fusi_make_clean(folder, 'Apply', true, 'Recursive', true)
%
% Options
%   'Apply'           false   write and replace files
%   'DeleteOriginal'  false   delete originals instead of moving to backup
%   'BackupDir'       '_pre_fix_backup'   subfolder for originals
%   'KeepAcqInfo'     true    save md fields to <name>_acqinfo.mat
%   'Recursive'       false   include subfolders
%
% Files named *_clean.mat and *.mat.bak are skipped as leftovers from
% earlier fixes and are listed at the end so you can remove them.

    p = localParseArgs(varargin);
    [files, strays] = localCollectFiles(target, p.Recursive);

    if isempty(files)
        fprintf('No .mat files to process at: %s\n', target);
        localReportStrays(strays);
        return;
    end

    fprintf('\n');
    if p.Apply
        fprintf('*** APPLY MODE: up to %d file(s) will be REWRITTEN ***\n', numel(files));
        if p.DeleteOriginal
            fprintf('    Originals will be DELETED after the new file is verified.\n');
        else
            fprintf('    Originals will be moved to the "%s" subfolder.\n', p.BackupDir);
        end
    else
        fprintf('DRY RUN over %d file(s). Nothing will be written or deleted.\n', numel(files));
        fprintf('Add ''Apply'', true when the preview looks right.\n');
    end
    fprintf('\n');

    nDone = 0; nSkip = 0; nFail = 0;

    for k = 1:numel(files)
        thisFile = files{k};
        [~, sName, sExt] = fileparts(thisFile);
        dispName = [sName sExt];

        try
            st = localCleanOne(thisFile, dispName, p);
        catch ME
            fprintf('  [FAIL] %s : %s\n', dispName, ME.message);
            fprintf('         original left untouched.\n');
            nFail = nFail + 1;
            continue;
        end

        switch st
            case 'done'
                nDone = nDone + 1;
            otherwise
                nSkip = nSkip + 1;
        end
    end

    fprintf('\n---------------------------------------------------------------\n');
    if p.Apply
        fprintf('Done. %d rewritten, %d already clean, %d failed.\n', nDone, nSkip, nFail);
    else
        fprintf('Dry run. %d would be rewritten, %d already clean, %d failed.\n', nDone, nSkip, nFail);
    end
    fprintf('---------------------------------------------------------------\n');

    localReportStrays(strays);
end

% =========================================================================
function status = localCleanOne(thisFile, dispName, p)

    status = 'skipped';

    vars = whos('-file', thisFile);
    varNames = {vars.name};

    if ~ismember('I', varNames)
        fprintf('  [skip] %s : no variable I\n', dispName);
        return;
    end

    idxI = find(strcmp(varNames, 'I'), 1);
    origSize = vars(idxI).size;

    % Already in GUI form?
    if ismember('metadata', varNames) && ismember('events', varNames) && ...
            ~ismember('md', varNames)
        fprintf('  [ok]   %s : already clean\n', dispName);
        return;
    end

    S = load(thisFile);

    % ---- metadata --------------------------------------------------------
    if isfield(S, 'metadata') && isstruct(S.metadata) && ~isempty(fieldnames(S.metadata))
        metadata = S.metadata;
        srcTxt = 'existing metadata';
    elseif isfield(S, 'md')
        metadata = localScannerFieldsFromMd(S.md);
        srcTxt = 'rebuilt from md';
    else
        fprintf('  [skip] %s : no metadata and no md\n', dispName);
        return;
    end

    if isempty(fieldnames(metadata))
        fprintf('  [skip] %s : could not determine scanner metadata\n', dispName);
        return;
    end

    % ---- events ----------------------------------------------------------
    if isfield(S, 'events') && isstruct(S.events)
        events = S.events;
    elseif isfield(S, 'md') && isstruct(S.md) && isfield(S.md, 'tag')
        events = S.md.tag;
    else
        events = struct();
        events.image = [];
        events.text = {};
    end

    I = S.I; %#ok<NASGU>

    fprintf('  [%s] %s   size(I) = [%s]   metadata: %s\n', ...
        localTag(p.Apply), dispName, localNumList(origSize), srcTxt);

    if isfield(metadata, 'imageSize')
        fprintf('           imageSize = [%s]\n', localNumList(metadata.imageSize));
    end

    if ismember('md', varNames)
        fprintf('           md will be removed from the data file\n');
    end

    status = 'done';

    if ~p.Apply
        return;
    end

    [folderPath, sName, sExt] = fileparts(thisFile);

    % ---- write the acquisition sidecar first ------------------------------
    if p.KeepAcqInfo && isfield(S, 'md')
        acqFile = fullfile(folderPath, [sName '_acqinfo.mat']);
        md = S.md; %#ok<NASGU>
        save(acqFile, 'md', '-v7');
    end

    % ---- write a temporary clean file -------------------------------------
    tmpFile = fullfile(folderPath, sprintf('%s__tmpclean_%06d%s', ...
        sName, round(rand * 1e6), sExt));

    if exist(tmpFile, 'file')
        delete(tmpFile);
    end

    save(tmpFile, 'I', 'metadata', 'events', '-v7.3');

    % ---- verify BEFORE touching the original ------------------------------
    vTmp = whos('-file', tmpFile);
    tmpNames = {vTmp.name};

    if ~all(ismember({'I', 'metadata', 'events'}, tmpNames))
        delete(tmpFile);
        error('temporary file is missing required variables.');
    end

    if ismember('md', tmpNames)
        delete(tmpFile);
        error('temporary file still contains md.');
    end

    idxTmpI = find(strcmp(tmpNames, 'I'), 1);
    if ~isequal(double(vTmp(idxTmpI).size), double(origSize))
        delete(tmpFile);
        error('size(I) changed during rewrite.');
    end

    % ---- retire the original ----------------------------------------------
    if p.DeleteOriginal
        delete(thisFile);
    else
        bakFolder = fullfile(folderPath, p.BackupDir);
        if ~exist(bakFolder, 'dir')
            mkdir(bakFolder);
        end

        bakTarget = fullfile(bakFolder, [sName sExt]);
        if exist(bakTarget, 'file')
            bakTarget = fullfile(bakFolder, sprintf('%s_%06d%s', sName, round(rand*1e6), sExt));
        end

        [okMove, msgMove] = movefile(thisFile, bakTarget, 'f');
        if ~okMove
            delete(tmpFile);
            error('could not move original to backup: %s', msgMove);
        end
    end

    % ---- promote the temporary file ---------------------------------------
    [okMove2, msgMove2] = movefile(tmpFile, thisFile, 'f');
    if ~okMove2
        error('clean file written as %s but could not be renamed: %s', tmpFile, msgMove2);
    end

    fprintf('           -> rewritten with I, metadata, events\n');
end

% =========================================================================
function metadataOut = localScannerFieldsFromMd(md)
    % Everything the acquisition script added is dropped; the rest is
    % treated as scanner-native so future scanner fields survive.

    dropExact = { ...
        'acquisition_mode', 'probe_type', 'tr_unit_s', 'nblocksImage', ...
        'data_size', 'data_ndims', 'is_volumetric', ...
        'timeIndex', 'sliceIndex'};

    dropPrefix = {'geom_', 'motor_', 'acq_', 'actual_', 'requested_', 'metadata_'};

    metadataOut = struct();

    if ~isstruct(md) || numel(md) ~= 1
        return;
    end

    fn = fieldnames(md);

    for i = 1:numel(fn)
        thisName = fn{i};

        if any(strcmp(thisName, dropExact))
            continue;
        end

        skipThis = false;
        for k = 1:numel(dropPrefix)
            if strncmp(thisName, dropPrefix{k}, numel(dropPrefix{k}))
                skipThis = true;
                break;
            end
        end

        if skipThis
            continue;
        end

        metadataOut.(thisName) = md.(thisName);
    end
end

% =========================================================================
function localReportStrays(strays)
    if isempty(strays)
        return;
    end

    fprintf('\nLeftover files from earlier fixes (not processed):\n');
    for i = 1:numel(strays)
        fprintf('   %s\n', strays{i});
    end
    fprintf('Delete them once you are satisfied with the rewritten files.\n');
end

% =========================================================================
function p = localParseArgs(args)
    p.Apply = false;
    p.DeleteOriginal = false;
    p.BackupDir = '_pre_fix_backup';
    p.KeepAcqInfo = true;
    p.Recursive = false;

    for i = 1:2:numel(args)
        if i+1 > numel(args)
            break;
        end
        switch lower(args{i})
            case 'apply'
                p.Apply = logical(args{i+1});
            case 'deleteoriginal'
                p.DeleteOriginal = logical(args{i+1});
            case 'backupdir'
                p.BackupDir = args{i+1};
            case 'keepacqinfo'
                p.KeepAcqInfo = logical(args{i+1});
            case 'recursive'
                p.Recursive = logical(args{i+1});
        end
    end
end

function [files, strays] = localCollectFiles(target, recursive)
    files = {};
    strays = {};

    if exist(target, 'file') == 2
        files = {target};
        return;
    end

    if exist(target, 'dir') ~= 7
        return;
    end

    d = dir(fullfile(target, '*.mat'));
    for i = 1:numel(d)
        if d(i).isdir
            continue;
        end

        thisName = d(i).name;

        % leftovers from earlier attempts
        if ~isempty(regexp(thisName, '_clean\.mat$', 'once')) || ...
                ~isempty(regexp(thisName, '_acqinfo\.mat$', 'once')) || ...
                ~isempty(regexp(thisName, '__tmpclean_', 'once'))
            strays{end+1} = fullfile(target, thisName); %#ok<AGROW>
            continue;
        end

        files{end+1} = fullfile(target, thisName); %#ok<AGROW>
    end

    % .bak files do not match *.mat, so list them separately
    db = dir(fullfile(target, '*.mat.bak'));
    for i = 1:numel(db)
        if ~db(i).isdir
            strays{end+1} = fullfile(target, db(i).name); %#ok<AGROW>
        end
    end

    if recursive
        sub = dir(target);
        for i = 1:numel(sub)
            if sub(i).isdir && ~strcmp(sub(i).name, '.') && ~strcmp(sub(i).name, '..')
                if strcmp(sub(i).name, '_pre_fix_backup')
                    continue;
                end
                [f2, s2] = localCollectFiles(fullfile(target, sub(i).name), true);
                files = [files f2]; %#ok<AGROW>
                strays = [strays s2]; %#ok<AGROW>
            end
        end
    end
end

function t = localTag(applyMode)
    if applyMode
        t = 'fix ';
    else
        t = 'plan';
    end
end

function s = localNumList(v)
    v = double(v(:)');
    parts = cell(1, numel(v));
    for i = 1:numel(v)
        if v(i) == round(v(i))
            parts{i} = sprintf('%d', v(i));
        else
            parts{i} = sprintf('%g', v(i));
        end
    end
    s = strjoin(parts, ' ');
end
