function varargout=deConfUSIon_utils(action,varargin)
% Consolidated stateless naming, display and filesystem helpers.
deConfUSIon_setup();
switch action
    case 'buildFooterLabel', [varargout{1:nargout}]=buildFooterLabel(varargin{:});
    case 'shortenMiddle', [varargout{1:nargout}]=shortenMiddle(varargin{:});
    case 'studio_mkdir', [varargout{1:nargout}]=studio_mkdir(varargin{:});
    case 'deConfUSIon_pcaica_scope_tag', [varargout{1:nargout}]=deConfUSIon_pcaica_scope_tag(varargin{:});
    case 'deConfUSIon_is_bad_display_name', [varargout{1:nargout}]=deConfUSIon_is_bad_display_name(varargin{:});
    case 'deConfUSIon_make_loaded_display_name', [varargout{1:nargout}]=deConfUSIon_make_loaded_display_name(varargin{:});
    case 'deConfUSIon_full_ordered_label_for_dataset', [varargout{1:nargout}]=deConfUSIon_full_ordered_label_for_dataset(varargin{:});
    case 'deConfUSIon_view_aspect', [varargout{1:nargout}]=deConfUSIon_view_aspect(varargin{:});
    case 'deConfUSIon_force_fullscreen_fig', [varargout{1:nargout}]=deConfUSIon_force_fullscreen_fig(varargin{:});
    case 'compact_chain_name', [varargout{1:nargout}]=deConfUSIon_compact_chain_name(varargin{:});
    case 'safe_preproc_save_path', [varargout{1:nargout}]=deConfUSIon_safe_preproc_save_path(varargin{:});
    case 'write_full_display_metadata', [varargout{1:nargout}]=deConfUSIon_write_full_display_metadata(varargin{:});
    case 'popup_polish', [varargout{1:nargout}]=deConfUSIon_popup_polish_now(varargin{:});
    case 'fix_scm_video_dialog_fonts', [varargout{1:nargout}]=deConfUSIon_fix_scm_video_dialog_fonts(varargin{:});
    case 'fc_stepmotor_read_folder', [varargout{1:nargout}]=deConfUSIon_FC_stepmotor_read_folder(varargin{:});
    case 'fc_force_layout', [varargout{1:nargout}]=deConfUSIon_FC_force_layout(varargin{:});
    case 'fc_remember_layout', [varargout{1:nargout}]=deConfUSIon_FC_remember_layout(varargin{:});
    otherwise, error('deConfUSIon:UtilityAction','Unknown utility: %s',action);
end
end
function s = buildFooterLabel()
person = 'Soner Caner Cagun';
tool = 'deConfUSIon';
inst = 'Max-Planck Institute for Biological Cybernetics';
dt = datestr(now,'yyyy-mm-dd HH:MM');
s = sprintf('%s - %s - %s - %s', person, tool, inst, dt);
end

function out = shortenMiddle(in, maxLen)
% shortenMiddle
% Safely shorten long labels/paths by preserving beginning and end.
% Needed by SCM / Video setup dialogs and dropdown labels.

if nargin < 1 || isempty(in)
    out = '';
    return;
end

if nargin < 2 || isempty(maxLen)
    maxLen = 120;
end

try
    if isstring(in)
        in = char(in);
    elseif isnumeric(in)
        in = num2str(in);
    elseif ~ischar(in)
        in = char(string(in));
    end
catch
    try
        in = char(in);
    catch
        in = '';
    end
end

maxLen = round(double(maxLen));
if ~isfinite(maxLen) || maxLen < 10
    maxLen = 10;
end

if numel(in) <= maxLen
    out = in;
    return;
end

ellipsisTxt = '...';
keep = maxLen - numel(ellipsisTxt);
frontN = ceil(keep * 0.60);
backN  = floor(keep * 0.40);

frontN = max(1, frontN);
backN  = max(1, backN);

if frontN + backN + numel(ellipsisTxt) > maxLen
    backN = max(1, maxLen - frontN - numel(ellipsisTxt));
end

out = [in(1:frontN) ellipsisTxt in(end-backN+1:end)];
end


function studio_mkdir(p)
if exist(p,'dir') ~= 7
    mkdir(p);
end
end
function tag = deConfUSIon_pcaica_scope_tag(scopeInfo)
tag = '';
try
    if isstruct(scopeInfo) && isfield(scopeInfo,'sliceSpecific') && scopeInfo.sliceSpecific
        tag = sprintf('sl%03dof%03d', round(scopeInfo.zIndex), round(scopeInfo.nSlices));
    end
catch
    tag = '';
end
end

function tf = deConfUSIon_is_bad_display_name(s)
% True if visible name looks like an internal temporary/preproc key.
tf = false;
if nargin < 1 || isempty(s), tf = true; return; end
try, s = char(s); catch, tf = true; return; end
low = lower(s);
bad = {'preproc_preproc','filter_filter','pca_pca','ica_ica','imreg_imreg','motor_motor'};
for i = 1:numel(bad)
    if ~isempty(strfind(low,bad{i})), tf = true; return; end
end
if ~isempty(strfind(s,'...')), tf = true; return; end
if ~isempty(regexp(low,'^preproc_[0-9a-f]{6,}','once')), tf = true; return; end
end

function out = deConfUSIon_make_loaded_display_name(datasetName, sourcePath, sourceFile)
% Visible RAW label for Studio dropdown.
% Preferred: animal_scanX_raw, e.g. 1005_scan3_raw.

if nargin < 1 || isempty(datasetName), datasetName = 'dataset'; end
if nargin < 2, sourcePath = ''; end
if nargin < 3, sourceFile = ''; end

try, datasetName = char(datasetName); catch, datasetName = 'dataset'; end
try, sourcePath  = char(sourcePath);  catch, sourcePath = ''; end
try, sourceFile  = char(sourceFile);  catch, sourceFile = ''; end

combo = [datasetName '_' sourceFile '_' sourcePath];

try
    out = deConfUSIon_display_name_from_sources(combo, [], '');
catch
    out = 'dataset_raw';
end

out = regexprep(out,'_(?:19|20)\d{6}_\d{6}$','');
out = regexprep(out,'_+','_');
out = regexprep(out,'^_+|_+$','');
if isempty(out), out = 'dataset_raw'; end
end

function label = deConfUSIon_full_ordered_label_for_dataset(nameIn, dataStruct, matFile)
% Return a stable ordered processing-chain label without truncation.
if nargin < 1 || isempty(nameIn), nameIn = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end
try
    label = deConfUSIon_display_name_from_sources(nameIn,dataStruct,matFile);
catch
    try, label = char(nameIn); catch, label = 'dataset'; end
    label = regexprep(label,'\.mat$','','ignorecase');
    label = strrep(label,'...','_');
    label = regexprep(label,'_+','_');
    label = regexprep(label,'^_+|_+$','');
end
if isempty(label), label = 'dataset'; end
end

function a = deConfUSIon_view_aspect(par)
%DECONFUSION_VIEW_ASPECT  In-plane display aspect ratio for fUSI images.
%   Used as set(ax,'DataAspectRatio',[1 a 1]), with a = dX/dY.  One
%   column pixel then occupies dX/dY times the height of one row pixel.
%   a == 1 is the legacy pixel-square behaviour. No data are resampled.
%
%   Resolution order:
%     1) par.probeViewAspect                    explicit override
%     2) dataset row/column spacing            physical size from the dataset
%     3) getpref deConfUSIon voxelSizeYX        [dY dX], any consistent unit
%     4) getpref deConfUSIon probeViewAspect    plain scalar
%     5) 1                                      unchanged legacy behaviour
%
%   Set once per rig, e.g.:
%     setpref('deConfUSIon','voxelSizeYX',[0.100 0.055])
%     setpref('deConfUSIon','probeViewAspect',1.6)

a = 1;
if nargin < 1 || ~isstruct(par), par = struct(); end

try
    if isfield(par,'probeViewAspect')
        v = double(par.probeViewAspect);
        if isscalar(v) && isfinite(v) && v > 0, a = v; return; end
    end
catch
end

try
    vs = [];
    if isfield(par,'voxelSizeUm'), vs = double(par.voxelSizeUm);
    elseif isfield(par,'voxelSize'), vs = double(par.voxelSize); end
    if isempty(vs) && isfield(par,'meta') && isstruct(par.meta)
        m = par.meta;
        if isfield(m,'voxelSize')
            vs = double(m.voxelSize);
        elseif isfield(m,'rawMetadata') && isstruct(m.rawMetadata) && isfield(m.rawMetadata,'voxelSize')
            vs = double(m.rawMetadata.voxelSize);
        end
    end
    if isempty(vs)
        calibration=scmSpatialCalibration(par);vs=calibration.spacingUm;
    end
    vs = vs(:).';
    if numel(vs) >= 2 && all(isfinite(vs(1:2)) & vs(1:2)>0)
        % DAR [1 a 1] makes one X pixel as long as a Y pixels.
        % Therefore a = column spacing / row spacing, not its inverse.
        v = vs(2)/vs(1);
        if isfinite(v) && v > 0, a = v; return; end
    end
catch
end

try
    vs=[];
    if ispref('deConfUSIon','voxelSizeYX'), vs=double(getpref('deConfUSIon','voxelSizeYX')); end
    vs = vs(:).';
    if numel(vs) >= 2 && all(isfinite(vs(1:2))) && all(vs(1:2) > 0)
        a = vs(2)/vs(1); return;
    end
catch
end

try
    v=1;
    if ispref('deConfUSIon','probeViewAspect'), v=double(getpref('deConfUSIon','probeViewAspect')); end
    if isscalar(v) && isfinite(v) && v > 0, a = v; return; end
catch
end

a = 1;
end

function deConfUSIon_force_fullscreen_fig(hFig)
% deConfUSIon_force_fullscreen_fig
% Opens normal MATLAB figure GUIs in a large/maximized window.
% MATLAB 2017b + 2023b compatible.

if nargin < 1 || isempty(hFig) || ~ishghandle(hFig)
    try
        hFig = gcf;
    catch
        return;
    end
end

try
    set(hFig,'Resize','on');
catch
end

try
    set(hFig,'Units','pixels');
catch
end

drawnow;

% Newer MATLAB versions: use true maximized state.
try
    if isprop(hFig,'WindowState')
        set(hFig,'WindowState','maximized');
        drawnow;
        return;
    end
catch
end

% MATLAB 2017b fallback: fill most of the screen.
try
    scr = get(0,'ScreenSize');
    margin = 25;
    W = max(1000, scr(3) - 2*margin);
    H = max(700,  scr(4) - 2*margin);
    set(hFig,'Position',[margin margin W H]);
    drawnow;
catch
end
end
