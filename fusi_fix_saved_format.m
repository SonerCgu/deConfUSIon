function fusi_fix_saved_format(target, varargin)
% FUSI_FIX_SAVED_FORMAT  Make already-acquired files load like GUI files.
%
% DRY RUN BY DEFAULT. Nothing is written until you pass 'Apply', true.
%
% The problem
%   The scanner GUI saves three variables:
%       I, metadata, events
%   where "metadata" holds only the scanner's own fields:
%       imageDim, imageSize, imageType, origen, t0, tag, time, voxelSize
%
%   The acquisition script saved only:
%       I, md
%   with those scanner fields buried among ~40 extra acquisition fields.
%   A loader looking for "metadata" found nothing, fell back to guessing
%   the geometry, and reported dim 2 (64) as the slice count instead of
%   dim 3 (54).
%
%   The pixel data was always correct. Only the variable naming was wrong,
%   so this is fully recoverable.
%
% What this does
%   For each file containing md but not metadata:
%       metadata = the scanner-native fields lifted back out of md
%       events   = md.tag, or an empty struct matching the GUI format
%   I and md are left untouched. Nothing is deleted.
%
% Usage
%   fusi_fix_saved_format('C:\Data\myexp')                    % preview
%   fusi_fix_saved_format('C:\Data\myexp', 'Apply', true)      % write
%   fusi_fix_saved_format(pwd, 'Recursive', true, 'Apply', true)
%   fusi_fix_saved_format(file, 'Apply', true, 'Backup', false)
%
% Safety
%   With 'Apply' true a .bak copy is made before each file is written,
%   unless 'Backup' is false. Files saved as -v7.3 are updated in place
%   without rewriting the large array.

    p = localParseArgs(varargin);
    files = localCollectFiles(target, p.Recursive);

    if isempty(files)
        fprintf('No .mat files found at: %s\n', target);
        return;
    end

    fprintf('\n');
    if p.Apply
        fprintf('*** APPLY MODE: up to %d file(s) will be MODIFIED ***\n', numel(files));
        if p.Backup
            fprintf('    A .bak copy is made before each write.\n');
        else
            fprintf('    Backups DISABLED.\n');
        end
    else
        fprintf('DRY RUN over %d file(s). Nothing will be written.\n', numel(files));
        fprintf('Add ''Apply'', true once the preview looks right.\n');
    end
    fprintf('\n');

    nFixed = 0; nSkip = 0; nFail = 0;

    for k = 1:numel(files)
        thisFile = files{k};
        [~, sName, sExt] = fileparts(thisFile);
        dispName = [sName sExt];

        try
            st = localFixOne(thisFile, dispName, p);
        catch ME
            fprintf('  [FAIL] %s : %s\n', dispName, ME.message);
            nFail = nFail + 1;
            continue;
        end

        switch st
            case 'fixed'
                nFixed = nFixed + 1;
            otherwise
                nSkip = nSkip + 1;
        end
    end

    fprintf('\n---------------------------------------------------------------\n');
    if p.Apply
        fprintf('Done. %d converted, %d skipped, %d failed.\n', nFixed, nSkip, nFail);
    else
        fprintf('Dry run. %d would be converted, %d skipped, %d failed.\n', nFixed, nSkip, nFail);
    end
    fprintf('---------------------------------------------------------------\n');
end

% =========================================================================
function status = localFixOne(thisFile, dispName, p)

    status = 'skipped';

    vars = whos('-file', thisFile);
    varNames = {vars.name};

    if ~ismember('md', varNames)
        fprintf('  [skip] %s : no variable md\n', dispName);
        return;
    end

    if ismember('metadata', varNames)
        fprintf('  [ok]   %s : already has metadata\n', dispName);
        return;
    end

    S = load(thisFile, 'md');
    md = S.md;

    if ~isstruct(md) || numel(md) ~= 1
        fprintf('  [skip] %s : md is not a scalar struct\n', dispName);
        return;
    end

    [metadata, events] = localBuildCompanyVars(md);

    mdFields = fieldnames(metadata);
    if isempty(mdFields)
        fprintf('  [skip] %s : no scanner fields found in md\n', dispName);
        return;
    end

    % report geometry so the conversion can be sanity checked
    szTxt = '';
    idxI = find(strcmp(varNames, 'I'), 1);
    if ~isempty(idxI)
        szTxt = sprintf('   size(I) = [%s]', localNumList(vars(idxI).size));
    end

    fprintf('  [%s] %s%s\n', localTag(p.Apply), dispName, szTxt);
    fprintf('           metadata <- %s\n', strjoin(mdFields', ', '));

    if isfield(metadata, 'imageSize')
        fprintf('           imageSize = [%s]\n', localNumList(metadata.imageSize));
    end

    status = 'fixed';

    if ~p.Apply
        return;
    end

    [folderPath, sName, sExt] = fileparts(thisFile);

    if p.Backup
        bakFile = fullfile(folderPath, [sName sExt '.bak']);
        if exist(bakFile, 'file') ~= 2
            copyfile(thisFile, bakFile);
        end
    end

    % Preferred: append the two variables without touching the big array.
    % Requires a v7.3 file, which is what the acquisition script writes for
    % volumetric data. -v7 files are rewritten in full instead.
    wroteViaMatfile = false;

    try
        mw = matfile(thisFile, 'Writable', true);
        mw.metadata = metadata;
        mw.events = events;
        wroteViaMatfile = true;
    catch
        wroteViaMatfile = false;
    end

    if ~wroteViaMatfile
        Sfull = load(thisFile);
        Sfull.metadata = metadata;
        Sfull.events = events;

        useV73 = false;
        if ~isempty(idxI) && vars(idxI).bytes > 1.5e9
            useV73 = true;
        end

        if useV73
            save(thisFile, '-struct', 'Sfull', '-v7.3');
        else
            save(thisFile, '-struct', 'Sfull', '-v7');
        end
    end

    % verify
    vNew = whos('-file', thisFile);
    if ~ismember('metadata', {vNew.name})
        error('metadata was not written.');
    end
end

% =========================================================================
function [metadataOut, eventsOut] = localBuildCompanyVars(md)
    % Fields added by the acquisition script. Everything else is treated as
    % scanner-native, so unknown scanner fields survive automatically.

    dropExact = { ...
        'acquisition_mode', 'probe_type', 'tr_unit_s', 'nblocksImage', ...
        'data_size', 'data_ndims', 'is_volumetric', ...
        'timeIndex', 'sliceIndex'};

    dropPrefix = {'geom_', 'motor_', 'acq_', 'actual_', 'requested_', 'metadata_'};

    metadataOut = struct();
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

    if isfield(md, 'tag')
        eventsOut = md.tag;
    else
        eventsOut = struct();
        eventsOut.image = [];
        eventsOut.text = {};
    end
end

% =========================================================================
function p = localParseArgs(args)
    p.Apply = false;
    p.Backup = true;
    p.Recursive = false;

    for i = 1:2:numel(args)
        if i+1 > numel(args)
            break;
        end
        switch lower(args{i})
            case 'apply'
                p.Apply = logical(args{i+1});
            case 'backup'
                p.Backup = logical(args{i+1});
            case 'recursive'
                p.Recursive = logical(args{i+1});
        end
    end
end

function files = localCollectFiles(target, recursive)
    files = {};

    if exist(target, 'file') == 2
        files = {target};
        return;
    end

    if exist(target, 'dir') ~= 7
        return;
    end

    d = dir(fullfile(target, '*.mat'));
    for i = 1:numel(d)
        if ~d(i).isdir
            files{end+1} = fullfile(target, d(i).name); %#ok<AGROW>
        end
    end

    if recursive
        sub = dir(target);
        for i = 1:numel(sub)
            if sub(i).isdir && ~strcmp(sub(i).name, '.') && ~strcmp(sub(i).name, '..')
                files = [files localCollectFiles(fullfile(target, sub(i).name), true)]; %#ok<AGROW>
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
