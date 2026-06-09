%% deConfUSIon PHASE 8 - lean root cleanup and post-clean audit
% Purpose:
%   Final conservative cleanup after Phase 6/7 repairs.
%
% This phase DOES:
%   - Archive old patch scripts from the root folder.
%   - Archive root-level report clutter (.tsv/.md/.txt logs from cleanup only).
%   - Keep required runtime helpers such as popup/timer/FC shared helpers.
%   - Keep run_fusi_studio.m because the toolbox still calls it internally.
%   - Write a clear report of remaining small files and why they should stay.
%
% This phase DOES NOT:
%   - Integrate more GUI/timer/callback helpers.
%   - Delete anything permanently.
%   - Move atlas source files rgb2acr.xlsx or list_selected_regions.txt.
%   - Move deConfUSIon_FC_find_stepmotor_txt_names.m if present.
%
% Usage:
%   run('D:\Github\HUMOR-Analysis-Tool\deConfUSIon_phase8_lean_cleanup.m')

clearvars -except root
clc

if exist('root','var') ~= 1 || isempty(root)
    root = 'D:\Github\HUMOR-Analysis-Tool';
end
root = char(regexprep(root,'[\\/]+$',''));

if exist(root,'dir') ~= 7
    error('Toolbox root not found: %s', root);
end

stamp = datestr(now,'yyyymmdd_HHMMSS');
archiveRoot = fullfile(root,'backups',['deConfUSIon_phase8_lean_cleanup_' stamp]);
patchDir = fullfile(archiveRoot,'archived_patch_scripts');
reportDir = fullfile(archiveRoot,'archived_root_reports');
mkdir(archiveRoot);
mkdir(patchDir);
mkdir(reportDir);

diaryFile = fullfile(archiveRoot,'phase8_console_log.txt');
try, diary(diaryFile); catch, end

fprintf('\n=== deConfUSIon PHASE 8: lean root cleanup ===\n');
fprintf('ROOT   : %s\n', root);
fprintf('ARCHIVE: %s\n\n', archiveRoot);

logFile = fullfile(archiveRoot,'phase8_action_log.tsv');
fidLog = fopen(logFile,'w');
fprintf(fidLog,'action\tstatus\tsource\tdestination\tdetails\n');

%% Keep backups/reports off MATLAB path
badRoots = {fullfile(root,'backups'), fullfile(root,'bakcups'), fullfile(root,'cleanup_reports')};
for bi = 1:numel(badRoots)
    if exist(badRoots{bi},'dir') == 7
        pp = regexp(genpath(badRoots{bi}), pathsep, 'split');
        for pi = 1:numel(pp)
            if isempty(pp{pi}), continue; end
            if ~isempty(strfind(path, pp{pi}))
                try, rmpath(pp{pi}); catch, end %#ok<CTCH>
            end
        end
    end
end
addpath(root,'-begin');

%% 1) Archive old patch scripts from root
fprintf('\n--- Archiving root patch scripts ---\n');

rootFiles = dir(root);
for i = 1:numel(rootFiles)
    if rootFiles(i).isdir, continue; end
    nm = rootFiles(i).name;

    if strcmpi(nm,'deConfUSIon_phase8_lean_cleanup.m')
        continue;
    end

    isPatch = false;
    isPatch = isPatch || ~isempty(regexpi(nm,'^deConfUSIon_phase[0-7].*\.m$','once'));
    isPatch = isPatch || ~isempty(regexpi(nm,'^deConfUSIon_.*(cleanup|repair|hotfix|finalize|audit).*\.m$','once'));
    isPatch = isPatch || ~isempty(regexpi(nm,'^HUMOR_.*patch.*\.m$','once'));

    if isPatch
        src = fullfile(root,nm);
        dst = fullfile(patchDir,nm);
        moveOne(src,dst,fidLog,'ARCHIVE_PATCH_SCRIPT');
    end
end

%% 2) Archive cleanup/report clutter from root only
fprintf('\n--- Archiving root cleanup report clutter ---\n');

rootFiles = dir(root);
for i = 1:numel(rootFiles)
    if rootFiles(i).isdir, continue; end
    nm = rootFiles(i).name;

    % Keep active atlas assets and normal project docs.
    if any(strcmpi(nm,{'rgb2acr.xlsx','list_selected_regions.txt','README.md'}))
        continue;
    end

    isReport = false;
    isReport = isReport || ~isempty(regexpi(nm,'^phase\d+_.*\.(tsv|txt|md)$','once'));
    isReport = isReport || ~isempty(regexpi(nm,'^file_reference_.*\.tsv$','once'));
    isReport = isReport || ~isempty(regexpi(nm,'^zero_active_reference_candidates\.tsv$','once'));
    isReport = isReport || ~isempty(regexpi(nm,'^duplicate_.*\.tsv$','once'));
    isReport = isReport || ~isempty(regexpi(nm,'^JM_atlas_color_order_integration_report\.txt$','once'));
    isReport = isReport || ~isempty(regexpi(nm,'^deConfUSIon_cleanup_report\.md$','once'));

    if isReport
        moveOne(fullfile(root,nm), fullfile(reportDir,nm), fidLog, 'ARCHIVE_ROOT_REPORT');
    end
end

%% 3) Keep-list sanity check
fprintf('\n--- Runtime helper keep-list sanity check ---\n');

mustKeep = { ...
    'run_fusi_studio.m', ...
    'run_deConfUSIon.m', ...
    'deConfUSIon.m', ...
    'deConfUSIon_popup_autofit_apply.m', ...
    'deConfUSIon_popup_autofit_timer.m', ...
    'deConfUSIon_popup_polish_now.m', ...
    'deConfUSIon_force_fullscreen_fig.m', ...
    'deConfUSIon_FC_force_layout.m', ...
    'deConfUSIon_FC_remember_layout.m', ...
    'deConfUSIon_FC_read_region_names_file.m', ...
    'deConfUSIon_FC_stepmotor_read_folder.m', ...
    'deConfUSIon_FC_find_stepmotor_txt_names.m', ...
    'deConfUSIon_find_stepmotor_seg_fc_files.m', ...
    'readFileList.m', ...
    'save_correct_colors.m', ...
    'deConfUSIon_prepare_atlas.m', ...
    'deConfUSIon_apply_rgb2acr.m' ...
};

fidKeep = fopen(fullfile(archiveRoot,'phase8_runtime_keep_check.tsv'),'w');
fprintf(fidKeep,'file\tstatus\twhich_result\n');

for i = 1:numel(mustKeep)
    f = fullfile(root,mustKeep{i});
    [~,base,~] = fileparts(mustKeep{i});

    w = which(base);
    if exist(f,'file') == 2
        status = 'OK_PRESENT';
    else
        status = 'MISSING_REVIEW';
    end

    fprintf('%-50s %s\n', mustKeep{i}, status);
    fprintf(fidKeep,'%s\t%s\t%s\n', mustKeep{i}, status, w);
end
fclose(fidKeep);

%% 4) Optional launcher simplification report, no action
% run_fusi_studio should stay because fusi_studio_GUI/fusi_studio_callback still
% call it. run_deConfUSIon is tiny but useful as branded launcher.
launcherNote = fullfile(archiveRoot,'phase8_launcher_decision.txt');
fidL = fopen(launcherNote,'w');
fprintf(fidL,'Launcher decision\n');
fprintf(fidL,'=================\n\n');
fprintf(fidL,'KEEP run_fusi_studio.m\n');
fprintf(fidL,'Reason: run_deConfUSIon.m calls it, and GUI/callback code may also call it internally.\n\n');
fprintf(fidL,'KEEP run_deConfUSIon.m\n');
fprintf(fidL,'Reason: branded launcher; harmless 257-byte compatibility wrapper.\n\n');
fprintf(fidL,'KEEP deConfUSIon.m\n');
fprintf(fidL,'Reason: main user-facing command.\n\n');
fclose(fidL);

%% 5) Fresh root inventory and classification
fprintf('\n--- Writing fresh active inventory ---\n');

rawDirs = regexp(genpath(root), pathsep, 'split');
activeFiles = {};
for di = 1:numel(rawDirs)
    d = rawDirs{di};
    if isempty(d), continue; end

    dl = lower(d);
    skip = false;
    skip = skip || ~isempty(strfind(dl,[filesep 'backups']));
    skip = skip || ~isempty(strfind(dl,[filesep 'bakcups']));
    skip = skip || ~isempty(strfind(dl,[filesep 'cleanup_reports']));
    skip = skip || ~isempty(strfind(dl,[filesep 'archived']));
    skip = skip || ~isempty(strfind(dl,[filesep '.git']));
    skip = skip || ~isempty(strfind(dl,[filesep '__macosx']));
    if skip, continue; end

    ff = dir(fullfile(d,'*.m'));
    for k = 1:numel(ff)
        activeFiles{end+1} = fullfile(d,ff(k).name); %#ok<SAGROW>
    end
end

% Read texts without comments
texts = cell(size(activeFiles));
bases = cell(size(activeFiles));
rels = cell(size(activeFiles));
for i = 1:numel(activeFiles)
    [~,bases{i},~] = fileparts(activeFiles{i});
    rels{i} = strrep(activeFiles{i},[root filesep],'');
    try
        t = fileread(activeFiles{i});
    catch
        t = '';
    end
    lines = regexp(t,'\r\n|\n|\r','split');
    for li = 1:numel(lines)
        lines{li} = regexprep(lines{li},'%.*$','');
    end
    texts{i} = sprintf('%s\n',lines{:});
end

inventoryFile = fullfile(archiveRoot,'phase8_active_m_file_inventory.tsv');
fidInv = fopen(inventoryFile,'w');
fprintf(fidInv,'file\tpath\tbytes\tactive_reference_count\tclassification\n');

smallFile = fullfile(archiveRoot,'phase8_remaining_small_files_under_2kb.tsv');
fidSmall = fopen(smallFile,'w');
fprintf(fidSmall,'file\tpath\tbytes\tactive_reference_count\tclassification\n');

deconfFile = fullfile(archiveRoot,'phase8_deConfUSIon_file_classification.tsv');
fidD = fopen(deconfFile,'w');
fprintf(fidD,'file\tpath\tbytes\tactive_reference_count\tclassification\n');

for i = 1:numel(activeFiles)
    info = dir(activeFiles{i});
    base = bases{i};

    tok = ['(?<![A-Za-z0-9_])' regexptranslate('escape',base) '(?![A-Za-z0-9_])'];
    refCount = 0;
    for j = 1:numel(activeFiles)
        if i == j, continue; end
        refCount = refCount + numel(regexp(texts{j},tok,'match'));
    end

    cls = classifyFile(base, refCount);

    fprintf(fidInv,'%s\t%s\t%d\t%d\t%s\n',base,rels{i},info.bytes,refCount,cls);

    if info.bytes <= 2048
        fprintf(fidSmall,'%s\t%s\t%d\t%d\t%s\n',base,rels{i},info.bytes,refCount,cls);
    end

    if ~isempty(regexpi(base,'deConfUSIon','once'))
        fprintf(fidD,'%s\t%s\t%d\t%d\t%s\n',base,rels{i},info.bytes,refCount,cls);
    end
end

fclose(fidInv);
fclose(fidSmall);
fclose(fidD);

%% 6) Remove empty folders under backup/report areas only
fprintf('\n--- Removing empty backup/report folders only ---\n');

safeRoots = {fullfile(root,'backups'), fullfile(root,'cleanup_reports'), fullfile(root,'bakcups')};
for ri = 1:numel(safeRoots)
    sr = safeRoots{ri};
    if exist(sr,'dir') ~= 7, continue; end
    dirs = regexp(genpath(sr), pathsep, 'split');
    [~,ord] = sort(cellfun(@numel,dirs),'descend');
    dirs = dirs(ord);

    for di = 1:numel(dirs)
        d = dirs{di};
        if isempty(d) || strcmpi(d,sr) || exist(d,'dir') ~= 7
            continue;
        end
        L = dir(d);
        names = setdiff({L.name},{'.','..'});
        if isempty(names)
            try
                rmdir(d);
                fprintf(fidLog,'REMOVE_EMPTY_DIR\tREMOVED\t%s\t\t\n',d);
            catch
            end
        end
    end
end

%% 7) Finish
for bi = 1:numel(badRoots)
    if exist(badRoots{bi},'dir') == 7
        pp = regexp(genpath(badRoots{bi}), pathsep, 'split');
        for pi = 1:numel(pp)
            if isempty(pp{pi}), continue; end
            if ~isempty(strfind(path, pp{pi}))
                try, rmpath(pp{pi}); catch, end %#ok<CTCH>
            end
        end
    end
end
addpath(root,'-begin');
rehash;
clear functions;

fprintf('\nDONE. Phase 8 lean cleanup complete.\n');
fprintf('Active .m files after cleanup: %d\n', numel(activeFiles));
fprintf('Archive/log folder: %s\n', archiveRoot);
fprintf('Inventory: %s\n', inventoryFile);
fprintf('Small-file report: %s\n', smallFile);
fprintf('deConfUSIon classification: %s\n', deconfFile);
fprintf('\nNow test:\n');
fprintf('  deConfUSIon\n');
fprintf('  FunctionalConnectivity\n');
fprintf('  qc_fusi\n');

fprintf(fidLog,'SUMMARY\tDONE\t\t\tactive_m_files=%d\n',numel(activeFiles));
fclose(fidLog);

try, diary off; catch, end

%% Local helpers
function moveOne(src,dst,fidLog,action)
    if exist(src,'file') ~= 2 && exist(src,'dir') ~= 7
        fprintf('SKIP missing: %s\n',src);
        fprintf(fidLog,'%s\tMISSING\t%s\t%s\t\n',action,src,dst);
        return;
    end
    dd = fileparts(dst);
    if exist(dd,'dir') ~= 7, mkdir(dd); end

    finalDst = dst;
    if exist(finalDst,'file') == 2 || exist(finalDst,'dir') == 7
        [p,n,e] = fileparts(dst);
        finalDst = fullfile(p,[n '_' datestr(now,'HHMMSSFFF') e]);
    end

    try
        movefile(src,finalDst);
        fprintf('MOVED: %s -> %s\n',src,finalDst);
        fprintf(fidLog,'%s\tMOVED\t%s\t%s\t\n',action,src,finalDst);
    catch ME
        fprintf('FAILED: %s -> %s | %s\n',src,finalDst,ME.message);
        fprintf(fidLog,'%s\tFAILED\t%s\t%s\t%s\n',action,src,finalDst,ME.message);
    end
end

function cls = classifyFile(base, refCount)
    b = lower(base);

    if any(strcmp(b,lower({'deConfUSIon','run_deConfUSIon','run_fusi_studio'})))
        cls = 'KEEP_LAUNCHER_COMPATIBILITY';
    elseif ~isempty(regexpi(base,'popup|timer|autofit|polish|fullscreen','once'))
        cls = 'KEEP_GUI_TIMER_CALLBACK_HELPER';
    elseif ~isempty(regexpi(base,'FC_force_layout|FC_remember_layout|FC_find_stepmotor|FC_read_region|FC_stepmotor|find_stepmotor','once'))
        cls = 'KEEP_SHARED_FC_STEPMOTOR_HELPER';
    elseif ~isempty(regexpi(base,'prepare_atlas|apply_rgb2acr|reorder_FC|fc_jm_order|readFileList|save_correct_colors','once'))
        cls = 'KEEP_JM_ATLAS_TOOL';
    elseif refCount == 0
        cls = 'REVIEW_ZERO_REF_BUT_KEPT';
    elseif refCount == 1
        cls = 'ONE_OWNER_KEEP_FOR_NOW';
    else
        cls = 'SHARED_KEEP';
    end
end
