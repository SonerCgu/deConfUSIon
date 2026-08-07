function apply_probe_aspect_patch(varargin)
% =========================================================================
% apply_probe_aspect_patch - fixes the squashed 3D-probe single-slice view
% =========================================================================
%   apply_probe_aspect_patch                      % patch files in this folder
%   apply_probe_aspect_patch('D:\Github\deConfUSIon')
%   apply_probe_aspect_patch(..., 'dryrun')       % report only
%   apply_probe_aspect_patch(..., 'revert')       % restore newest backup
%
% WHAT IT DOES
%   In play_fusi_video_final.m and SCM_gui.m, ONLY when nZ > 1 (a 3D probe
%   stack), it sets the display axes' DataAspectRatio so the tall probe
%   slice is shown with a correctable proportion. The 2D and 2D+motor paths
%   (nZ == 1) are never reached by the new code, so they are untouched.
%
%   Default proportion factor is 1.0 (identical to today). To widen the tall
%   probe image, set probeViewAspect > 1 - either by editing the one marked
%   line in each file, or by passing par.probeViewAspect from the caller.
%
% SAFETY
%   - copies each original into <root>\probe_aspect_backup_<timestamp>\ first
%   - each anchor must occur EXACTLY once or that file is skipped
%   - idempotent: re-running detects the marker and does nothing
% =========================================================================

root = '';
dryRun = false; doRevert = false;
for k = 1:numel(varargin)
    a = varargin{k};
    if ~ischar(a), continue; end
    switch lower(strtrim(a))
        case {'dryrun','dry','-dryrun'}, dryRun = true;
        case {'revert','undo','-revert'}, doRevert = true;
        otherwise, root = a;
    end
end
if isempty(root)
    root = fileparts(mfilename('fullpath'));
    if isempty(root), root = pwd; end
end
if exist(root,'dir') ~= 7
    error('apply_probe_aspect_patch:NoRoot','Folder not found: %s', root);
end

fprintf('\n=== 3D probe aspect fix ===\nFolder: %s\n', root);

if doRevert
    localRevert(root); return;
end

dataFile = fullfile(root,'probe_aspect_patch_data.txt');
if exist(dataFile,'file') ~= 2
    error('apply_probe_aspect_patch:NoData', ...
        'probe_aspect_patch_data.txt must sit next to the .m files (in %s).', root);
end

raw = fileread(dataFile);
raw = strrep(raw, sprintf('\r\n'), sprintf('\n'));
pat = '<<<PATCH ([A-Z])\|([^|]+)\|(.*?)>>>\s*\n<<<FIND>>>\n(.*?)\n<<<REPLACE>>>\n(.*?)\n<<<END>>>';
tok = regexp(raw, pat, 'tokens');
if isempty(tok)
    error('apply_probe_aspect_patch:BadData','Could not parse the patch data file.');
end

stamp  = datestr(now,'yyyymmdd_HHMMSS');
bakDir = fullfile(root, ['probe_aspect_backup_' stamp]);
touched = {};
nApplied = 0; nSkipped = 0; nFailed = 0;

for k = 1:numel(tok)
    name   = tok{k}{1};
    target = strtrim(tok{k}{2});
    marker = tok{k}{3};
    findT  = tok{k}{4};
    replT  = tok{k}{5};

    tgt = fullfile(root, target);
    if exist(tgt,'file') ~= 2
        fprintf('  [%s] %-26s NOT FOUND - skipped\n', name, target);
        nFailed = nFailed + 1; continue;
    end
    txt = fileread(tgt);

    if ~isempty(strfind(txt, sprintf('\r\n')))
        nl = sprintf('\r\n');
    else
        nl = sprintf('\n');
    end
    findX = strrep(findT, sprintf('\n'), nl);
    replX = strrep(replT, sprintf('\n'), nl);

    if ~isempty(strfind(txt, marker))
        fprintf('  [%s] %-26s already patched - skipped\n', name, target);
        nSkipped = nSkipped + 1; continue;
    end

    nHit = numel(strfind(txt, findX));
    if nHit ~= 1
        fprintf(2,'  [%s] %-26s anchor found %d times (need 1) - REFUSED\n', name, target, nHit);
        nFailed = nFailed + 1; continue;
    end

    if dryRun
        fprintf('  [%s] %-26s OK (dry run)\n', name, target);
        nApplied = nApplied + 1; continue;
    end

    if ~any(strcmp(touched, target))
        if exist(bakDir,'dir') ~= 7, mkdir(bakDir); end
        copyfile(tgt, fullfile(bakDir, target));
        touched{end+1} = target; %#ok<AGROW>
    end

    fid = fopen(tgt,'w');
    if fid < 0
        error('apply_probe_aspect_patch:NoWrite','Cannot write %s (open elsewhere / read-only?).', tgt);
    end
    fwrite(fid, strrep(txt, findX, replX));
    fclose(fid);

    fprintf('  [%s] %-26s patched\n', name, target);
    nApplied = nApplied + 1;
end

fprintf('\nApplied %d | skipped %d | refused %d\n', nApplied, nSkipped, nFailed);
if dryRun
    fprintf('Dry run - nothing written.\n\n'); return;
end
if ~isempty(touched)
    fprintf('Originals backed up to: %s\n', bakDir);
end
fprintf(['\nNext:\n' ...
    '  1) clear functions\n' ...
    '  2) reopen the video / SCM GUI on a 3D probe dataset\n' ...
    '  3) if the slice is still too tall, open each file, find\n' ...
    '     "probeViewAspect = 1.0;" and raise it (try 1.4, 1.6, 2.0)\n' ...
    '     - or pass par.probeViewAspect from the studio.\n' ...
    'Revert anytime: apply_probe_aspect_patch(''%s'',''revert'')\n\n'], root);
end

function localRevert(root)
d = dir(fullfile(root,'probe_aspect_backup_*'));
d = d([d.isdir]);
if isempty(d), fprintf(2,'No backups found in %s\n', root); return; end
[~,ix] = sort({d.name}); bak = fullfile(root, d(ix(end)).name);
f = dir(fullfile(bak,'*.m'));
for k = 1:numel(f)
    copyfile(fullfile(bak,f(k).name), fullfile(root,f(k).name));
    fprintf('  restored %s\n', f(k).name);
end
fprintf('Restored from %s\nRun: clear functions\n\n', bak);
end
