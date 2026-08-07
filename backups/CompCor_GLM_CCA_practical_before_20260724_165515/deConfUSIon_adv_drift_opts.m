function cfg = deConfUSIon_adv_drift_opts(method, defs)
% Advanced options for CompCor variants, injection artifacts, and CCA.
cfg = struct();
cfg.cancelled = false;
if nargin < 1 || isempty(method), method = ''; end
if nargin < 2 || isempty(defs), defs = struct(); end
method = lower(char(method));
TR = localGet(defs,'TR',1);
I = [];
try, if isfield(defs,'I'), I = defs.I; end, catch, end
inj = localGet(defs,'injectionSec',60);
resp = localGet(defs,'responseSec',180);

if strcmp(method,'compcor') || strcmp(method,'acompcor')
    choices = { ...
        'Global brain signal', ...
        'tCompCor: highest temporal SD voxels', ...
        'aCompCor: manually selected non-responsive / WM-CSF-like ROI', ...
        'Random CompCor: random size-matched voxels', ...
        'Low-variance CompCor: lowest temporal SD voxels'};
    [ix,ok] = listdlg('PromptString','CompCor confound source', ...
        'ListString',choices,'SelectionMode','single', ...
        'InitialValue',2,'ListSize',[420 150]);
    if ~ok, cfg.cancelled = true; return; end
    modes = {'global','tcompcor','acompcor','random','lowvar'};
    cfg.compcorMode = modes{ix};

    answ = inputdlg({ ...
        'Number of regressors / PCs', ...
        'Voxel fraction for automatic masks, e.g. 0.05 = 5%', ...
        'Protect expected response? 1=yes, 0=no', ...
        'Injection onset [s]', ...
        'Protected response duration [s]', ...
        'Random seed'}, ...
        'CompCor settings',1, ...
        {'5','0.05','1',num2str(inj),num2str(resp),'1'});
    if isempty(answ), cfg.cancelled = true; return; end
    cfg.nComp = max(1,round(str2double(answ{1})));
    cfg.compcorFrac = str2double(answ{2});
    cfg.protectResponse = logical(str2double(answ{3}));
    cfg.injectionSec = str2double(answ{4});
    cfg.responseSec = str2double(answ{5});
    cfg.randomSeed = round(str2double(answ{6}));
    if ~isfinite(cfg.compcorFrac) || cfg.compcorFrac <= 0, cfg.compcorFrac = 0.05; end
    if ~isfinite(cfg.injectionSec), cfg.injectionSec = inj; end
    if ~isfinite(cfg.responseSec) || cfg.responseSec <= 0, cfg.responseSec = resp; end
    if ~isfinite(cfg.randomSeed), cfg.randomSeed = 1; end

    if strcmp(cfg.compcorMode,'acompcor')
        q = questdlg(['aCompCor should use a deliberately selected non-responsive / WM-CSF-like ROI. ' ...
            'Paint this ROI now?'],'aCompCor ROI','Paint ROI','Cancel','Paint ROI');
        if ~strcmp(q,'Paint ROI'), cfg.cancelled = true; return; end
        if isempty(I), errordlg('No image data available for ROI picker.'); cfg.cancelled = true; return; end
        try
            cfg.refMask = deConfUSIon_drift_roi_picker(I,'title','aCompCor noise ROI','brushSize',15);
        catch ME
            errordlg(['ROI picker failed: ' ME.message]); cfg.cancelled = true; return;
        end
        if isempty(cfg.refMask), cfg.cancelled = true; return; end
    end
    return;
end

if strcmp(method,'glm') || strcmp(method,'model')
    choices = { ...
        'None: drift + protected response only', ...
        'Automatic injection basis', ...
        'Artifact ROI PCs only', ...
        'Automatic basis + artifact ROI PCs', ...
        'Custom MAT/CSV/TXT regressors', ...
        'Automatic basis + custom regressors', ...
        'Paper-style spatial CCA: brain vs noise ROI', ...
        'Automatic basis + spatial CCA'};
    [ix,ok] = listdlg('PromptString','GLM artifact / CCA nuisance model', ...
        'ListString',choices,'SelectionMode','single', ...
        'InitialValue',2,'ListSize',[520 180]);
    if ~ok, cfg.cancelled = true; return; end
    modes = {'none','auto','roi','auto_roi','custom','auto_custom','spatial_cca','auto_spatial_cca'};
    cfg.artifactMode = modes{ix};

    answ = inputdlg({ ...
        'Injection onset [s]', ...
        'Protected response duration [s]', ...
        'Short pulse duration [s]', ...
        'Exponential taus [s], space-separated', ...
        'Add persistent step? 1=yes, 0=no', ...
        'Add slow plateau/ramp? 1=yes, 0=no', ...
        'Artifact/CCA PCs or threshold'}, ...
        'GLM artifact settings',1, ...
        {num2str(inj),num2str(resp),'5','5 20 60','0','1','3'});
    if isempty(answ), cfg.cancelled = true; return; end
    cfg.injectionSec = str2double(answ{1});
    cfg.responseSec = str2double(answ{2});
    cfg.artifactPulseSec = str2double(answ{3});
    cfg.artifactExpTauSec = str2num(answ{4}); %#ok<ST2NM>
    cfg.artifactPersistent = logical(str2double(answ{5}));
    cfg.artifactPlateau = logical(str2double(answ{6}));
    cfg.artifactNPC = max(1,round(str2double(answ{7})));
    cfg.ccaThreshold = cfg.artifactNPC;
    if ~isfinite(cfg.injectionSec), cfg.injectionSec = inj; end
    if ~isfinite(cfg.responseSec) || cfg.responseSec <= 0, cfg.responseSec = resp; end
    if ~isfinite(cfg.artifactPulseSec) || cfg.artifactPulseSec <= 0, cfg.artifactPulseSec = 5; end
    if isempty(cfg.artifactExpTauSec), cfg.artifactExpTauSec = [5 20 60]; end

    needsArtifactROI = any(strcmp(cfg.artifactMode,{'roi','auto_roi'}));
    needsCCA = any(strcmp(cfg.artifactMode,{'spatial_cca','auto_spatial_cca'}));
    needsCustom = any(strcmp(cfg.artifactMode,{'custom','auto_custom'}));

    if needsArtifactROI
        q = questdlg('Paint local injection/bubble artifact ROI now?','Artifact ROI','Paint ROI','Cancel','Paint ROI');
        if ~strcmp(q,'Paint ROI'), cfg.cancelled = true; return; end
        if isempty(I), errordlg('No image data available for ROI picker.'); cfg.cancelled = true; return; end
        cfg.artifactMask = deConfUSIon_drift_roi_picker(I,'title','Injection / bubble artifact ROI','brushSize',15);
        if isempty(cfg.artifactMask), cfg.cancelled = true; return; end
    end

    if needsCCA
        q = questdlg(['Paper-style spatial CCA needs a noise/non-functional area. ' ...
            'Paint noise area now?'],'CCA noise area','Paint noise ROI','Cancel','Paint noise ROI');
        if ~strcmp(q,'Paint noise ROI'), cfg.cancelled = true; return; end
        if isempty(I), errordlg('No image data available for ROI picker.'); cfg.cancelled = true; return; end
        cfg.ccaNoiseMask = deConfUSIon_drift_roi_picker(I,'title','CCA noise / non-functional area','brushSize',20);
        if isempty(cfg.ccaNoiseMask), cfg.cancelled = true; return; end
    end

    if needsCustom
        [fn,fp] = uigetfile({'*.mat;*.csv;*.txt','Regressor files (*.mat, *.csv, *.txt)'}, ...
            'Select custom artifact regressors');
        if isequal(fn,0), cfg.cancelled = true; return; end
        cfg.customArtifactFile = fullfile(fp,fn);
    end
    return;
end
end

function v = localGet(s,n,d)
v = d;
try
    if isfield(s,n) && ~isempty(s.(n)), v = s.(n); end
catch
end
end
