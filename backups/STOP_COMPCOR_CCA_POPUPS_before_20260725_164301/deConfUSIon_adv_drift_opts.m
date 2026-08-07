function cfg = deConfUSIon_adv_drift_opts(method, defs)
% Advanced visible options for CompCor variants, injection artifacts and CCA.
% Called by deConfUSIon_drift_dialog.m before returning cfg.

cfg = struct();
cfg.cancelled = false;

if nargin < 1 || isempty(method), method = ''; end
if nargin < 2 || isempty(defs), defs = struct(); end

method = lower(char(method));

I = [];
try
    if isfield(defs,'I') && ~isempty(defs.I), I = defs.I; end
catch
end

TR = 1;
try
    if isfield(defs,'TR') && ~isempty(defs.TR), TR = double(defs.TR(end)); end
catch
end

inj = 60;
try
    if isfield(defs,'injectionSec') && ~isempty(defs.injectionSec), inj = double(defs.injectionSec(1)); end
catch
end

resp = 180;
try
    if isfield(defs,'responseSec') && ~isempty(defs.responseSec), resp = double(defs.responseSec(1)); end
catch
end

if any(strcmp(method,{'compcor','acompcor'}))
    choices = { ...
        'Global brain signal regression', ...
        'tCompCor: 5 PCs from highest temporal-SD voxels', ...
        'aCompCor: 5 PCs from manually painted non-responsive / WM-CSF-like ROI', ...
        'Random CompCor: PCs from random size-matched brain mask', ...
        'Low-variance CompCor: PCs from lowest temporal-SD voxels'};

    [ix,ok] = listdlg( ...
        'PromptString','Select CompCor / confound regression mode', ...
        'ListString',choices, ...
        'SelectionMode','single', ...
        'InitialValue',2, ...
        'ListSize',[560 180]);

    if ~ok
        cfg.cancelled = true;
        return;
    end

    modes = {'global','tcompcor','acompcor','random','lowvar'};
    cfg.compcorMode = modes{ix};

    answ = inputdlg({ ...
        'Number of regressors / PCs', ...
        'Automatic voxel fraction, e.g. 0.05 = 5%', ...
        'Protect expected PACAP/drug response? 1=yes, 0=no', ...
        'Injection onset [s]', ...
        'Protected response duration [s]', ...
        'Random seed'}, ...
        'CompCor settings',1, ...
        {'5','0.05','1',num2str(inj),num2str(resp),'1'});

    if isempty(answ)
        cfg.cancelled = true;
        return;
    end

    cfg.nComp = max(1,round(str2double(answ{1})));
    cfg.compcorFrac = str2double(answ{2});
    cfg.protectResponse = logical(str2double(answ{3}));
    cfg.injectionSec = str2double(answ{4});
    cfg.responseSec = str2double(answ{5});
    cfg.randomSeed = round(str2double(answ{6}));

    if ~isfinite(cfg.compcorFrac) || cfg.compcorFrac <= 0, cfg.compcorFrac = 0.05; end
    if cfg.compcorFrac > 1, cfg.compcorFrac = cfg.compcorFrac/100; end
    if ~isfinite(cfg.injectionSec), cfg.injectionSec = inj; end
    if ~isfinite(cfg.responseSec) || cfg.responseSec <= 0, cfg.responseSec = resp; end
    if ~isfinite(cfg.randomSeed), cfg.randomSeed = 1; end

    if strcmp(cfg.compcorMode,'acompcor')
        if isempty(I)
            errordlg('No image data available for aCompCor ROI painting.','aCompCor');
            cfg.cancelled = true;
            return;
        end
        q = questdlg(['aCompCor should use a deliberately selected non-responsive / WM-CSF-like ROI. ' ...
            'Paint this ROI now?'], ...
            'aCompCor ROI', ...
            'Paint ROI','Cancel','Paint ROI');
        if ~strcmp(q,'Paint ROI')
            cfg.cancelled = true;
            return;
        end
        try
            mk = deConfUSIon_drift_roi_picker(I,'title','aCompCor non-responsive / WM-CSF-like ROI','brushSize',15);
        catch ME
            errordlg(['ROI picker failed: ' ME.message],'aCompCor ROI');
            cfg.cancelled = true;
            return;
        end
        if isempty(mk)
            cfg.cancelled = true;
            return;
        end
        cfg.refMask = mk;
    end

    return;
end

if any(strcmp(method,{'glm','model'}))
    choices = { ...
        'None: drift + protected response only', ...
        'Automatic injection artefact basis', ...
        'Artifact ROI PCs only: injection/bubble/coupling area', ...
        'Automatic basis + artifact ROI PCs', ...
        'Custom MAT/CSV/TXT artefact regressors', ...
        'Automatic basis + custom regressors', ...
        'CCA: paper-style spatial CCA, brain vs noise ROI', ...
        'Automatic basis + CCA'};

    [ix,ok] = listdlg( ...
        'PromptString','Select GLM artefact / CCA nuisance model', ...
        'ListString',choices, ...
        'SelectionMode','single', ...
        'InitialValue',2, ...
        'ListSize',[620 210]);

    if ~ok
        cfg.cancelled = true;
        return;
    end

    modes = {'none','auto','roi','auto_roi','custom','auto_custom','spatial_cca','auto_spatial_cca'};
    cfg.artifactMode = modes{ix};

    answ = inputdlg({ ...
        'Injection onset [s]', ...
        'Protected response duration [s]', ...
        'Short injection pulse duration [s]', ...
        'Exponential decay taus [s], space-separated', ...
        'Add persistent step? 1=yes, 0=no', ...
        'Add slow plateau/ramp? 1=yes, 0=no', ...
        'Artifact ROI PCs / CCA threshold'}, ...
        'GLM artefact / CCA settings',1, ...
        {num2str(inj),num2str(resp),'5','5 20 60','0','1','3'});

    if isempty(answ)
        cfg.cancelled = true;
        return;
    end

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
        if isempty(I)
            errordlg('No image data available for artefact ROI painting.','Artefact ROI');
            cfg.cancelled = true;
            return;
        end
        q = questdlg('Paint the local injection / bubble / coupling artefact ROI now?', ...
            'Artefact ROI','Paint ROI','Cancel','Paint ROI');
        if ~strcmp(q,'Paint ROI')
            cfg.cancelled = true;
            return;
        end
        mk = deConfUSIon_drift_roi_picker(I,'title','Injection / bubble / coupling artefact ROI','brushSize',15);
        if isempty(mk)
            cfg.cancelled = true;
            return;
        end
        cfg.artifactMask = mk;
    end

    if needsCCA
        if isempty(I)
            errordlg('No image data available for CCA noise ROI painting.','CCA');
            cfg.cancelled = true;
            return;
        end
        q = questdlg(['CCA needs a noise / non-functional area. ' ...
            'Paint this area now?'], ...
            'CCA noise ROI','Paint noise ROI','Cancel','Paint noise ROI');
        if ~strcmp(q,'Paint noise ROI')
            cfg.cancelled = true;
            return;
        end
        mk = deConfUSIon_drift_roi_picker(I,'title','CCA noise / non-functional area','brushSize',20);
        if isempty(mk)
            cfg.cancelled = true;
            return;
        end
        cfg.ccaNoiseMask = mk;
    end

    if needsCustom
        [fn,fp] = uigetfile({'*.mat;*.csv;*.txt','Regressor files (*.mat, *.csv, *.txt)'}, ...
            'Select custom artefact regressors');
        if isequal(fn,0)
            cfg.cancelled = true;
            return;
        end
        cfg.customArtifactFile = fullfile(fp,fn);
    end

    return;
end
end
