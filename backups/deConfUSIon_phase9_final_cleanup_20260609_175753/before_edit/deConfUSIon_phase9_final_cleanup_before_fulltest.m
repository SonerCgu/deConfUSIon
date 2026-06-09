%% deConfUSIon PHASE 9 - final cleanup before full 2D / 2D-motor testing
% Purpose:
%   Conservative final cleanup for the current deConfUSIon toolbox state.
%
% This patch DOES:
%   1) Archive root patch scripts/report clutter.
%   2) Integrate run_deConfUSIon.m into deConfUSIon.m and archive run_deConfUSIon.m.
%   3) KEEP run_fusi_studio.m because the split GUI still depends on it.
%   4) Rename studio_load_options_dark_dialog_patch16.m to
%      studio_load_options_dark_dialog.m and patch callers.
%   5) Move manual JM utilities out of the root into atlas_tools:
%        - save_correct_colors.m
%        - deConfUSIon_reorder_FC_by_list.m
%      These are manual tools, not required for automatic atlas registration.
%   6) Archive atlas_tools/matlab_functions.rar because it was only JM's
%      source package; the needed functions/data are now installed.
%   7) Archive studio_mkdir.m only if no active runtime source references it.
%   8) Compress old backup folders into ZIP files and remove the old folders
%      after successful ZIP creation.
%   9) Write final inventory reports.
%
% This patch DOES NOT:
%   - Delete anything permanently without a ZIP/archive copy.
%   - Move rgb2acr.xlsx or list_selected_regions.txt.
%   - Move readFileList.m, deConfUSIon_prepare_atlas.m, or deConfUSIon_apply_rgb2acr.m.
%   - Move step-motor / FC shared helper files.
%   - Move popup/timer/autofit GUI helpers.
%
% Usage:
%   run('D:\Github\HUMOR-Analysis-Tool\deConfUSIon_phase9_final_cleanup_before_fulltest.m')

clearvars -except root
clc

%% USER-SAFE SETTINGS
ZIP_OLD_BACKUPS = true;
REMOVE_OLD_BACKUP_FOLDERS_AFTER_ZIP = true;  % ZIP is kept before folder removal.

if exist('root','var') ~= 1 || isempty(root)
    root = 'D:\Github\HUMOR-Analysis-Tool';
end
root = char(regexprep(root,'[\\/]+$',''));

if exist(root,'dir') ~= 7
    error('Toolbox root not found: %s', root);
end

stamp = datestr(now,'yyyymmdd_HHMMSS');
archiveRoot = fullfile(root,'backups',['deConfUSIon_phase9_final_cleanup_' stamp]);
beforeEditDir = fullfile(archiveRoot,'before_edit');
patchDir = fullfile(archiveRoot,'archived_patch_scripts');
reportDir = fullfile(archiveRoot,'archived_root_reports');
manualAtlasDir = fullfile(archiveRoot,'moved_manual_atlas_tools_originals');
legacyDir = fullfile(archiveRoot,'archived_legacy_wrappers');
clutterDir = fullfile(archiveRoot,'archived_source_packages_and_zero_ref');
mkdir(archiveRoot);
mkdir(beforeEditDir);
mkdir(patchDir);
mkdir(reportDir);
mkdir(manualAtlasDir);
mkdir(legacyDir);
mkdir(clutterDir);

diaryFile = fullfile(archiveRoot,'phase9_console_log.txt');
try, diary(diaryFile); catch, end

fprintf('\n=== deConfUSIon PHASE 9: final cleanup before full test ===\n');
fprintf('ROOT   : %s\n', root);
fprintf('ARCHIVE: %s\n\n', archiveRoot);

logFile = fullfile(archiveRoot,'phase9_action_log.tsv');
fidLog = fopen(logFile,'w');
fprintf(fidLog,'action\tstatus\tsource\tdestination\tdetails\n');

%% Clean path from backup/report folders
removeBackupReportPaths(root);
addpath(root,'-begin');

%% ------------------------------------------------------------------------
% 1) Archive old patch scripts and report clutter from root
% -------------------------------------------------------------------------
fprintf('\n--- 1) Archiving root patch scripts and reports ---\n');

rootFiles = dir(root);
for i = 1:numel(rootFiles)
    if rootFiles(i).isdir, continue; end
    nm = rootFiles(i).name;

    if strcmpi(nm,'deConfUSIon_phase9_final_cleanup_before_fulltest.m')
        continue;
    end

    isPatch = false;
    isPatch = isPatch || ~isempty(regexpi(nm,'^deConfUSIon_phase[0-8].*\.m$','once'));
    isPatch = isPatch || ~isempty(regexpi(nm,'^deConfUSIon_.*(cleanup|repair|hotfix|finalize|audit).*\.m$','once'));

    if isPatch
        moveOne(fullfile(root,nm), fullfile(patchDir,nm), fidLog, 'ARCHIVE_PATCH_SCRIPT');
    end
end

rootFiles = dir(root);
for i = 1:numel(rootFiles)
    if rootFiles(i).isdir, continue; end
    nm = rootFiles(i).name;

    if any(strcmpi(nm,{'README.md','rgb2acr.xlsx','list_selected_regions.txt'}))
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

%% ------------------------------------------------------------------------
% 2) Integrate run_deConfUSIon into deConfUSIon
% -------------------------------------------------------------------------
fprintf('\n--- 2) Integrating run_deConfUSIon into deConfUSIon ---\n');

deFile = fullfile(root,'deConfUSIon.m');
runDeFile = fullfile(root,'run_deConfUSIon.m');

if exist(deFile,'file') == 2
    copyfile(deFile, fullfile(beforeEditDir,'deConfUSIon_before_phase9.m'));

    newDe = sprintf([ ...
        'function deConfUSIon()\n' ...
        '%% deConfUSIon - main launcher for deConfUSIon / fUSI Studio.\n' ...
        '%% This directly calls run_fusi_studio because the split GUI runtime still\n' ...
        '%% depends on fusi_studio_GUI.m + fusi_studio_callback.m assembly.\n' ...
        '\n' ...
        'root = fileparts(mfilename(''fullpath''));\n' ...
        'if isempty(root), root = pwd; end\n' ...
        'addpath(root,''-begin'');\n' ...
        '\n' ...
        'atlasTools = fullfile(root,''atlas_tools'');\n' ...
        'if exist(atlasTools,''dir'') == 7\n' ...
        '    addpath(atlasTools,''-begin'');\n' ...
        'end\n' ...
        '\n' ...
        'run_fusi_studio;\n' ...
        'end\n' ...
        ]);
    writeTextFile(deFile, newDe);
    fprintf('Updated deConfUSIon.m to call run_fusi_studio directly.\n');
    fprintf(fidLog,'INTEGRATE_LAUNCHER\tUPDATED_DECONFUSION\t%s\t\t\n',deFile);
else
    fprintf('WARNING: deConfUSIon.m missing; launcher integration skipped.\n');
    fprintf(fidLog,'INTEGRATE_LAUNCHER\tMISSING_DECONFUSION\t%s\t\t\n',deFile);
end

% Patch any active raw references to run_deConfUSIon -> run_fusi_studio.
patchRawReferences(root, 'run_deConfUSIon', 'run_fusi_studio', beforeEditDir, fidLog);

% Archive run_deConfUSIon if no active refs remain.
if exist(runDeFile,'file') == 2
    if countRawRefs(root,'run_deConfUSIon',runDeFile) == 0
        moveOne(runDeFile, fullfile(legacyDir,'run_deConfUSIon.m'), fidLog, 'ARCHIVE_INTEGRATED_LAUNCHER');
    else
        fprintf('KEEP run_deConfUSIon.m because references remain.\n');
        fprintf(fidLog,'ARCHIVE_INTEGRATED_LAUNCHER\tKEPT_REFERENCED\t%s\t\t\n',runDeFile);
    end
end

%% ------------------------------------------------------------------------
% 3) Rename active load dialog helper to remove patch16 name
% -------------------------------------------------------------------------
fprintf('\n--- 3) Renaming studio_load_options_dark_dialog_patch16 ---\n');

oldDlg = fullfile(root,'studio_load_options_dark_dialog_patch16.m');
newDlg = fullfile(root,'studio_load_options_dark_dialog.m');

if exist(oldDlg,'file') == 2
    if exist(newDlg,'file') ~= 2
        oldTxt = fileread(oldDlg);
        newTxt = regexprep(oldTxt, ...
            '(?<![A-Za-z0-9_])studio_load_options_dark_dialog_patch16(?![A-Za-z0-9_])', ...
            'studio_load_options_dark_dialog');
        writeTextFile(newDlg, newTxt);
        fprintf('Created studio_load_options_dark_dialog.m\n');
        fprintf(fidLog,'RENAME_DIALOG_HELPER\tCREATED_NEW\t%s\t%s\t\n',oldDlg,newDlg);
    else
        fprintf('studio_load_options_dark_dialog.m already exists.\n');
    end

    patchRawReferences(root, ...
        'studio_load_options_dark_dialog_patch16', ...
        'studio_load_options_dark_dialog', ...
        beforeEditDir, fidLog);

    if countRawRefs(root,'studio_load_options_dark_dialog_patch16',oldDlg) == 0
        moveOne(oldDlg, fullfile(legacyDir,'studio_load_options_dark_dialog_patch16.m'), fidLog, 'ARCHIVE_RENAMED_DIALOG_HELPER');
    else
        fprintf('KEEP old dialog helper because references remain.\n');
        fprintf(fidLog,'ARCHIVE_RENAMED_DIALOG_HELPER\tKEPT_REFERENCED\t%s\t\t\n',oldDlg);
    end
else
    fprintf('Old patch16 dialog helper not found; probably already renamed/archived.\n');
end

%% ------------------------------------------------------------------------
% 4) Move manual atlas utilities into atlas_tools
% -------------------------------------------------------------------------
fprintf('\n--- 4) Moving manual atlas utilities into atlas_tools ---\n');

atlasDir = fullfile(root,'atlas_tools');
if exist(atlasDir,'dir') ~= 7
    mkdir(atlasDir);
end

manualAtlasFiles = { ...
    'save_correct_colors.m', ...
    'deConfUSIon_reorder_FC_by_list.m' ...
};

for i = 1:numel(manualAtlasFiles)
    src = fullfile(root, manualAtlasFiles{i});
    dst = fullfile(atlasDir, manualAtlasFiles{i});

    if exist(src,'file') ~= 2
        fprintf('SKIP manual atlas utility missing from root: %s\n', manualAtlasFiles{i});
        continue;
    end

    % Only move if active runtime does not reference the root file by direct filename.
    % Function calls will still work after deConfUSIon adds atlas_tools to path.
    if exist(dst,'file') == 2
        copyfile(src, fullfile(manualAtlasDir, manualAtlasFiles{i}));
        moveOne(src, fullfile(manualAtlasDir, ['root_duplicate_' manualAtlasFiles{i}]), fidLog, 'ARCHIVE_DUPLICATE_MANUAL_ATLAS_TOOL');
    else
        try
            copyfile(src, fullfile(manualAtlasDir, manualAtlasFiles{i}));
        catch
        end
        moveOne(src, dst, fidLog, 'MOVE_MANUAL_ATLAS_TOOL_TO_ATLAS_TOOLS');
    end
end

% Archive original JM source package if present; it is no longer runtime data.
jmRar = fullfile(atlasDir,'matlab_functions.rar');
if exist(jmRar,'file') == 2
    moveOne(jmRar, fullfile(clutterDir,'matlab_functions.rar'), fidLog, 'ARCHIVE_JM_SOURCE_RAR');
end

%% ------------------------------------------------------------------------
% 5) Archive zero-ref studio_mkdir only if truly unused in raw active source
% -------------------------------------------------------------------------
fprintf('\n--- 5) Archiving zero-reference tiny leftovers ---\n');

zeroRefCandidates = { ...
    'studio_mkdir.m' ...
};

for i = 1:numel(zeroRefCandidates)
    src = fullfile(root,zeroRefCandidates{i});
    if exist(src,'file') ~= 2
        continue;
    end
    [~,base,~] = fileparts(src);
    c = countRawRefs(root,base,src);
    if c == 0
        moveOne(src, fullfile(clutterDir,zeroRefCandidates{i}), fidLog, 'ARCHIVE_ZERO_REF_TINY_HELPER');
    else
        fprintf('KEEP %s because raw references remain: %d\n', zeroRefCandidates{i}, c);
        fprintf(fidLog,'ARCHIVE_ZERO_REF_TINY_HELPER\tKEPT_REFERENCED\t%s\t\trefs=%d\n',src,c);
    end
end

%% ------------------------------------------------------------------------
% 6) Brand cleanup in run_fusi_studio, but keep file
% -------------------------------------------------------------------------
fprintf('\n--- 6) Branding cleanup inside run_fusi_studio, keeping file ---\n');

rfs = fullfile(root,'run_fusi_studio.m');
if exist(rfs,'file') == 2
    copyfile(rfs, fullfile(beforeEditDir,'run_fusi_studio_before_phase9.m'));
    txt = fileread(rfs);
    txt = strrep(txt, 'HUMOR_fUSI_Studio_runtime', 'deConfUSIon_fUSI_Studio_runtime');
    txt = strrep(txt, 'HUMoR:IconCopy', 'deConfUSIon:IconCopy');
    txt = strrep(txt, 'HUMoR:SplitAssemble', 'deConfUSIon:SplitAssemble');
    txt = strrep(txt, 'HUMoR / fUSI Studio', 'deConfUSIon / fUSI Studio');
    txt = strrep(txt, 'HUMOR_ICON_COPY_PATCH_20260518B', 'deConfUSIon icon copy');
    txt = strrep(txt, 'HUMOR_ICON_COPY_PATCH_20260518', 'deConfUSIon icon copy');
    writeTextFile(rfs, txt);
    fprintf('Cleaned visible legacy branding inside run_fusi_studio.m\n');
    fprintf(fidLog,'BRAND_CLEANUP\tPATCHED\t%s\t\t\n',rfs);
end

%% ------------------------------------------------------------------------
% 7) Compress old backups
% -------------------------------------------------------------------------
fprintf('\n--- 7) Compressing old backup folders ---\n');

if ZIP_OLD_BACKUPS
    backupsRoot = fullfile(root,'backups');
    zipDir = fullfile(backupsRoot, ['compressed_old_backups_' stamp]);
    if exist(zipDir,'dir') ~= 7
        mkdir(zipDir);
    end

    if exist(backupsRoot,'dir') == 7
        B = dir(backupsRoot);
        for i = 1:numel(B)
            if ~B(i).isdir, continue; end
            nm = B(i).name;
            if strcmp(nm,'.') || strcmp(nm,'..'), continue; end
            if strcmp(nm, ['deConfUSIon_phase9_final_cleanup_' stamp]), continue; end
            if strcmp(nm, ['compressed_old_backups_' stamp]), continue; end
            if ~isempty(strfind(nm,'compressed_old_backups')), continue; end

            srcDir = fullfile(backupsRoot,nm);
            zipFile = fullfile(zipDir,[nm '.zip']);

            try
                zip(zipFile, srcDir);
                ok = exist(zipFile,'file') == 2 && dir(zipFile).bytes > 0;
                if ok
                    fprintf('ZIPPED backup folder: %s\n', nm);
                    fprintf(fidLog,'ZIP_BACKUP_FOLDER\tZIPPED\t%s\t%s\t\n',srcDir,zipFile);

                    if REMOVE_OLD_BACKUP_FOLDERS_AFTER_ZIP
                        try
                            rmdir(srcDir,'s');
                            fprintf('REMOVED old backup folder after ZIP: %s\n', nm);
                            fprintf(fidLog,'ZIP_BACKUP_FOLDER\tREMOVED_AFTER_ZIP\t%s\t%s\t\n',srcDir,zipFile);
                        catch ME_rm
                            fprintf('Could not remove old backup folder %s: %s\n', nm, ME_rm.message);
                            fprintf(fidLog,'ZIP_BACKUP_FOLDER\tZIP_OK_REMOVE_FAILED\t%s\t%s\t%s\n',srcDir,zipFile,ME_rm.message);
                        end
                    end
                else
                    fprintf('ZIP failed or empty for: %s\n', nm);
                    fprintf(fidLog,'ZIP_BACKUP_FOLDER\tZIP_EMPTY_OR_FAILED\t%s\t%s\t\n',srcDir,zipFile);
                end
            catch ME_zip
                fprintf('ZIP failed for %s: %s\n', nm, ME_zip.message);
                fprintf(fidLog,'ZIP_BACKUP_FOLDER\tZIP_FAILED\t%s\t%s\t%s\n',srcDir,zipFile,ME_zip.message);
            end
        end
    end
end

%% ------------------------------------------------------------------------
% 8) Final inventory
% -------------------------------------------------------------------------
fprintf('\n--- 8) Writing final inventory reports ---\n');

removeBackupReportPaths(root);
addpath(root,'-begin');
rehash;
clear functions;

[activeFiles,bases,rels,bytes] = collectActiveMFiles(root);

inventoryFile = fullfile(archiveRoot,'phase9_active_m_file_inventory.tsv');
fidInv = fopen(inventoryFile,'w');
fprintf(fidInv,'file\tpath\tbytes\tclassification\n');
for i = 1:numel(activeFiles)
    cls = classifyActiveFile(bases{i});
    fprintf(fidInv,'%s\t%s\t%d\t%s\n',bases{i},rels{i},bytes(i),cls);
end
fclose(fidInv);

smallFile = fullfile(archiveRoot,'phase9_remaining_small_files_under_2kb.tsv');
fidS = fopen(smallFile,'w');
fprintf(fidS,'file\tpath\tbytes\tclassification\n');
for i = 1:numel(activeFiles)
    if bytes(i) <= 2048
        cls = classifyActiveFile(bases{i});
        fprintf(fidS,'%s\t%s\t%d\t%s\n',bases{i},rels{i},bytes(i),cls);
    end
end
fclose(fidS);

decisionFile = fullfile(archiveRoot,'phase9_final_decisions.txt');
fidD = fopen(decisionFile,'w');
fprintf(fidD,'deConfUSIon final cleanup decisions\n');
fprintf(fidD,'===================================\n\n');
fprintf(fidD,'run_fusi_studio.m: KEPT. Required to assemble fusi_studio_GUI.m + fusi_studio_callback.m into runtime.\n');
fprintf(fidD,'run_deConfUSIon.m: integrated into deConfUSIon.m and archived if no references remained.\n');
fprintf(fidD,'save_correct_colors.m: moved to atlas_tools as manual JM utility; not needed for automatic registration.\n');
fprintf(fidD,'readFileList.m: kept in root because deConfUSIon_prepare_atlas uses it.\n');
fprintf(fidD,'deConfUSIon_apply_rgb2acr.m: kept in root because automatic atlas preparation uses it.\n');
fprintf(fidD,'studio_load_options_dark_dialog_patch16.m: renamed to studio_load_options_dark_dialog.m.\n');
fprintf(fidD,'studio_resolve_paths.m: KEPT. Used by GroupAnalysis_Common and GroupAnalysis_FC.\n');
fprintf(fidD,'studio_mkdir.m: archived only if zero raw references remained.\n');
fprintf(fidD,'popup/timer/autofit helpers: KEPT. Risky to integrate because GUI/timer callbacks call them by name.\n');
fprintf(fidD,'FC/step-motor helpers: KEPT. Shared across FunctionalConnectivity and Studio/segmentation workflows.\n');
fprintf(fidD,'atlas_tools/rgb2acr.xlsx and list_selected_regions.txt: KEPT. Required for JM colors/order.\n');
fprintf(fidD,'atlas_tools/matlab_functions.rar: archived. Source package only, not runtime.\n');
fclose(fidD);

fprintf('\nDONE. Phase 9 final cleanup complete.\n');
fprintf('Active .m files now: %d\n', numel(activeFiles));
fprintf('Archive/log folder : %s\n', archiveRoot);
fprintf('Inventory          : %s\n', inventoryFile);
fprintf('Small-file report  : %s\n', smallFile);
fprintf('Decision report    : %s\n', decisionFile);

fprintf('\nNow do your full test:\n');
fprintf('  deConfUSIon\n');
fprintf('Then test: load normal 2D data, load 2D step-motor data, QC, FC, segmentation, atlas registration.\n');

fprintf(fidLog,'SUMMARY\tDONE\t\t\tactive_m_files=%d\n',numel(activeFiles));
fclose(fidLog);
try, diary off; catch, end

%% =========================================================================
% Helper functions
% =========================================================================

function patchRawReferences(root, oldName, newName, backupDir, fidLog)
    [files,~,rels,~] = collectActiveMFiles(root);
    pat = ['(?<![A-Za-z0-9_])' regexptranslate('escape',oldName) '(?![A-Za-z0-9_])'];
    for i = 1:numel(files)
        f = files{i};
        [~,base,~] = fileparts(f);
        if strcmp(base, oldName), continue; end

        try
            txt = fileread(f);
        catch
            continue;
        end
        newTxt = regexprep(txt, pat, newName);

        if ~strcmp(txt,newTxt)
            bfile = fullfile(backupDir, strrep(rels{i},filesep,'__'));
            if exist(bfile,'file') ~= 2
                copyfile(f,bfile);
            end
            writeTextFile(f,newTxt);
            fprintf('PATCHED reference %s -> %s in %s\n', oldName, newName, rels{i});
            fprintf(fidLog,'PATCH_RAW_REFERENCES\tPATCHED\t%s\t\t%s -> %s\n',rels{i},oldName,newName);
        end
    end
end

function n = countRawRefs(root, targetBase, selfPath)
    [files,~,~,~] = collectActiveMFiles(root);
    pat = ['(?<![A-Za-z0-9_])' regexptranslate('escape',targetBase) '(?![A-Za-z0-9_])'];
    n = 0;
    for i = 1:numel(files)
        if strcmpi(files{i}, selfPath)
            continue;
        end
        try
            txt = fileread(files{i});
        catch
            txt = '';
        end
        n = n + numel(regexp(txt,pat,'match'));
    end
end

function [files,bases,rels,bytes] = collectActiveMFiles(root)
    rawDirs = regexp(genpath(root), pathsep, 'split');
    files = {};
    bases = {};
    rels = {};
    bytes = [];
    for di = 1:numel(rawDirs)
        d = rawDirs{di};
        if isempty(d), continue; end
        dl = lower(d);
        skip = false;
        skip = skip || hasPathPart(dl,'backups');
        skip = skip || hasPathPart(dl,'bakcups');
        skip = skip || hasPathPart(dl,'cleanup_reports');
        skip = skip || hasPathPart(dl,'archived');
        skip = skip || hasPathPart(dl,'.git');
        skip = skip || hasPathPart(dl,'__macosx');
        if skip, continue; end

        ff = dir(fullfile(d,'*.m'));
        for k = 1:numel(ff)
            f = fullfile(d,ff(k).name);
            [~,b,~] = fileparts(ff(k).name);
            files{end+1} = f; %#ok<AGROW>
            bases{end+1} = b; %#ok<AGROW>
            rels{end+1} = relPath(f,root); %#ok<AGROW>
            bytes(end+1) = ff(k).bytes; %#ok<AGROW>
        end
    end
end

function tf = hasPathPart(p, part)
    sep = lower(filesep);
    part = lower(part);
    tf = ~isempty(strfind(p,[sep part sep]));
    if ~tf && numel(p) >= numel([sep part])
        tf = strcmp(p(end-numel([sep part])+1:end), [sep part]);
    end
end

function r = relPath(f, root)
    if numel(f) > numel(root)+1
        r = f(numel(root)+2:end);
    else
        [~,n,e] = fileparts(f);
        r = [n e];
    end
end

function writeTextFile(f, txt)
    fid = fopen(f,'w');
    if fid < 0
        error('Could not open for writing: %s', f);
    end
    fwrite(fid,txt,'char');
    fclose(fid);
end

function moveOne(src,dst,fidLog,action)
    if exist(src,'file') ~= 2 && exist(src,'dir') ~= 7
        fprintf('SKIP missing: %s\n',src);
        fprintf(fidLog,'%s\tMISSING\t%s\t%s\t\n',action,src,dst);
        return;
    end

    dd = fileparts(dst);
    if exist(dd,'dir') ~= 7
        mkdir(dd);
    end

    finalDst = dst;
    if exist(finalDst,'file') == 2 || exist(finalDst,'dir') == 7
        [p,n,e] = fileparts(dst);
        finalDst = fullfile(p,[n '_' datestr(now,'HHMMSSFFF') e]);
    end

    try
        movefile(src, finalDst);
        fprintf('MOVED: %s -> %s\n',src,finalDst);
        fprintf(fidLog,'%s\tMOVED\t%s\t%s\t\n',action,src,finalDst);
    catch ME
        fprintf('FAILED: %s -> %s | %s\n',src,finalDst,ME.message);
        fprintf(fidLog,'%s\tFAILED\t%s\t%s\t%s\n',action,src,finalDst,ME.message);
    end
end

function removeBackupReportPaths(root)
    badRoots = {fullfile(root,'backups'), fullfile(root,'bakcups'), fullfile(root,'cleanup_reports')};
    for bi = 1:numel(badRoots)
        if exist(badRoots{bi},'dir') ~= 7
            continue;
        end
        pp = regexp(genpath(badRoots{bi}), pathsep, 'split');
        for pi = 1:numel(pp)
            if isempty(pp{pi}), continue; end
            if ~isempty(strfind(path, pp{pi}))
                try, rmpath(pp{pi}); catch, end %#ok<CTCH>
            end
        end
    end
end

function cls = classifyActiveFile(base)
    b = lower(base);
    if any(strcmp(b, lower({'deConfUSIon','run_fusi_studio'})))
        cls = 'KEEP_LAUNCHER_RUNTIME';
    elseif ~isempty(regexpi(base,'popup|timer|autofit|polish|fullscreen','once'))
        cls = 'KEEP_GUI_TIMER_CALLBACK';
    elseif ~isempty(regexpi(base,'FC_find_stepmotor|FC_stepmotor|FC_read_region|FC_force_layout|FC_remember_layout|find_stepmotor','once'))
        cls = 'KEEP_SHARED_FC_STEPMOTOR';
    elseif ~isempty(regexpi(base,'prepare_atlas|apply_rgb2acr|readFileList|fc_jm_order','once'))
        cls = 'KEEP_JM_ATLAS_RUNTIME';
    elseif ~isempty(regexpi(base,'studio_resolve_paths|studio_load_options_dark_dialog','once'))
        cls = 'KEEP_STUDIO_RUNTIME_HELPER';
    else
        cls = 'KEEP_ACTIVE_TOOLBOX_FILE';
    end
end
