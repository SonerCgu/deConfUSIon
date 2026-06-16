function outFile = fc_export_group_analysis_bundle_interactive(s)
% Robust standalone FC GroupAnalysis exporter for deConfUSIon.
% Exports ROI R/Z, heatmap, timecourses, seed maps/timecourses, compare ROI, and slice FC.

outFile = '';
if nargin < 1 || ~isstruct(s)
    error('Expected FunctionalConnectivity GUI state struct as input.');
end

fcBundle = localMakeBundle(s);

tag = localSafe(localGetc(s,'tag',datestr(now,'yyyymmdd_HHMMSS')));
saveRoot = localGetc(s,'saveRoot','');
qcDir = localGetc(s,'qcDir','');

startDir = '';
if ~isempty(saveRoot) && exist(saveRoot,'dir') == 7
    startDir = fullfile(saveRoot,'Connectivity','GroupBundles');
    if exist(startDir,'dir') ~= 7
        try, mkdir(startDir); catch, startDir = saveRoot; end
    end
end
if isempty(startDir) && ~isempty(qcDir) && exist(qcDir,'dir') == 7
    startDir = qcDir;
end
if isempty(startDir), startDir = pwd; end

defaultName = ['FC_GroupBundle_' tag '.mat'];
[f,p] = uiputfile('*.mat','Save FC GroupBundle for GroupAnalysis',fullfile(startDir,defaultName));
if isequal(f,0) || isequal(p,0)
    return;
end
outFile = fullfile(p,f);
[pp,nn,ee] = fileparts(outFile);
if isempty(ee), ee = '.mat'; end
if isempty(strfind(nn,'FC_GroupBundle_'))
    nn = ['FC_GroupBundle_' nn];
end
outFile = fullfile(pp,[nn ee]);

save(outFile,'fcBundle','-v7.3');

% Also save/copy into standard GroupAnalysis bundle folder when possible.
try
    if ~isempty(saveRoot) && exist(saveRoot,'dir') == 7
        autoDir = fullfile(saveRoot,'GroupAnalysis','Bundles','FC');
        if exist(autoDir,'dir') ~= 7, mkdir(autoDir); end
        autoFile = fullfile(autoDir,[nn ee]);
        if ~strcmpi(autoFile,outFile)
            save(autoFile,'fcBundle','-v7.3');
        end
    end
catch
end

fprintf('\n[deConfUSIon FC] Exported FC GroupAnalysis bundle:\n%s\n',outFile);
end

function fcBundle = localMakeBundle(s)
fcBundle = struct();
fcBundle.version = 'FC_GroupBundle_v2_rich_external_20260616';
fcBundle.created = datestr(now,31);
fcBundle.tag = localGetc(s,'tag',datestr(now,'yyyymmdd_HHMMSS'));
fcBundle.saveRoot = localGetc(s,'saveRoot','');
fcBundle.qcDir = localGetc(s,'qcDir','');
fcBundle.note = ['R = Pearson correlation for display. Z = Fisher z for group statistics. ' ...
                 'Bundle contains ROI matrices, heatmaps, mean timecourses, seed maps/timecourses, ' ...
                 'compare-ROI vectors/maps, and step-motor sliceResults when available.'];

fcBundle.settings = localSettings(s);
fcBundle.subjects = struct([]);

nSub = 0;
try, nSub = numel(s.subjects); catch, nSub = 0; end

for i = 1:nSub
    subj = s.subjects(i);
    rec = localEmptySubject();
    rec.name = localGetc(subj,'name',sprintf('Subject_%02d',i));
    rec.group = localGetc(subj,'group','');
    rec.TR = localGetn(subj,'TR',NaN);
    rec.analysisDir = localGetc(subj,'analysisDir','');
    rec.isStepMotor3D = localGetn(s,'Z',1) > 1;
    rec.nSlices = localGetn(s,'Z',1);

    res = localCurrentROI(s,i);
    if ~isempty(res) && isstruct(res) && isfield(res,'M') && ~isempty(res.M)
        rec.hasROI = true;
        rec.epochName = localGetc(res,'epochName','');
        rec.timeIdx = localGet(res,'timeIdx',[]);
        rec.labels = double(localGet(res,'labels',[])); rec.labels = rec.labels(:);
        rec.names = localCellstr(localGet(res,'names',{}));
        rec.counts = double(localGet(res,'counts',[])); rec.counts = rec.counts(:);
        rec.meanTS = double(localGet(res,'meanTS',[]));
        rec.R = double(res.M);
        rec.M = rec.R;
        rec.Z = localR2Z(rec.R);
        rec.statMatrix = rec.Z;
        rec.displayMatrix = rec.R;
        rec.displayZ = rec.Z;
        rec.displayStatMatrix = rec.Z;
        rec.displayNames = rec.names;
        rec.displayLabels = rec.labels;
        rec.heatmap = struct('R',rec.R,'Z',rec.Z,'labels',rec.labels,'names',{rec.names});
        rec.compareROI = localCompareROI(s,subj,rec.labels,rec.names,rec.R,rec.Z,rec.meanTS,rec.timeIdx,rec.TR);
        rec.sliceResults = localBuildSliceBundle(s,i,res);
    end

    rec.seedResults = localSubjectSeedResults(s,i);
    rec.allEpochs = localAllEpochs(s,i);
    fcBundle.subjects(i) = rec;
end
end

function S = localSettings(s)
S = struct();
S.currentSubject = localGetn(s,'currentSubject',NaN);
S.currentEpoch = localGetn(s,'currentEpoch',NaN);
S.analysisStartSec = localGetn(s,'analysisStartSec',NaN);
S.analysisEndSec = localGetn(s,'analysisEndSec',NaN);
S.roiOrder = localGetc(s,'roiOrder','');
S.roiHemiMode = localGetc(s,'roiHemiMode','');
S.compareROI = localGetn(s,'compareROI',NaN);
S.seedX = localGetn(s,'seedX',NaN);
S.seedY = localGetn(s,'seedY',NaN);
S.seedZ = localGetn(s,'slice',NaN);
S.seedBoxSize = localGetn(s,'seedBoxSize',NaN);
S.useSliceOnly = localGet(s,'useSliceOnly',false);
S.note = 'Use Fisher Z for group statistics; use Pearson R for visualization.';
end

function rec = localEmptySubject()
rec = struct('name','','group','','TR',NaN,'analysisDir','','hasROI',false, ...
    'epochName','','timeIdx',[],'labels',[],'names',{{}},'counts',[],'meanTS',[], ...
    'R',[],'M',[],'Z',[],'statMatrix',[],'statSpace','Fisher z', ...
    'displayMatrix',[],'displaySpace','Pearson r', ...
    'displayNames',{{}},'displayLabels',[],'displayZ',[],'displayStatMatrix',[], ...
    'heatmap',struct(),'compareROI',struct(), ...
    'isStepMotor3D',false,'nSlices',[],'sliceResults',struct([]), ...
    'seedResults',struct([]),'allEpochs',struct([]));
end

function res = localCurrentROI(s,i)
res = [];
try
    C = s.roiResults;
    curEp = round(localGetn(s,'currentEpoch',1));
    if iscell(C) && i <= size(C,1) && curEp <= size(C,2)
        res = C{i,curEp};
    end
    if isempty(res) && iscell(C) && i <= size(C,1)
        for e = 1:size(C,2)
            if ~isempty(C{i,e})
                res = C{i,e};
                return;
            end
        end
    end
catch
    res = [];
end
end

function sliceResults = localBuildSliceBundle(s,subIdx,resWhole)
sliceResults = struct([]);
try
    nZ = round(localGetn(s,'Z',1));
    if nZ < 2 || isempty(resWhole), return; end
    n = 0;
    for z = 1:nZ
        ss = s;
        ss.slice = z;
        ss.sliceRegionOnly = true;
        rz = deConfUSIon_FC_make_slice_roi_result(ss,subIdx,resWhole,z);
        if isempty(rz) || ~isstruct(rz) || ~isfield(rz,'M') || isempty(rz.M), continue; end
        if ~isfield(rz,'labels') || numel(rz.labels) < 2, continue; end
        if ~isfield(rz,'sliceOnly') || ~rz.sliceOnly, continue; end
        n = n + 1;
        R = double(rz.M);
        Zm = localR2Z(R);
        sliceResults(n).sliceIndex = z; %#ok<AGROW>
        sliceResults(n).sliceLabel = sprintf('Slice%03d',z);
        sliceResults(n).labels = double(rz.labels(:));
        sliceResults(n).names = localCellstr(localGet(rz,'names',{}));
        sliceResults(n).counts = double(localGet(rz,'counts',[]));
        sliceResults(n).meanTS = double(localGet(rz,'meanTS',[]));
        sliceResults(n).timeIdx = localGet(rz,'timeIdx',[]);
        sliceResults(n).R = R;
        sliceResults(n).M = R;
        sliceResults(n).Z = Zm;
        sliceResults(n).statMatrix = Zm;
        sliceResults(n).statSpace = 'Fisher z';
        sliceResults(n).displayMatrix = R;
        sliceResults(n).displaySpace = 'Pearson r';
        sliceResults(n).sliceOnly = true;
    end
catch
    sliceResults = struct([]);
end
end

function seedOut = localSubjectSeedResults(s,i)
seedOut = struct([]);
try
    C = s.seedResults;
    if ~iscell(C) || i > size(C,1), return; end
    n = 0;
    for e = 1:size(C,2)
        sr = C{i,e};
        if isempty(sr) || ~isstruct(sr), continue; end
        n = n + 1;
        seedOut(n) = localSeedStruct(sr,e); %#ok<AGROW>
    end
catch
    seedOut = struct([]);
end
end

function out = localSeedStruct(sr,e)
out = struct();
out.epochIndex = e;
out.epochName = localGetc(sr,'epochName',sprintf('epoch_%d',e));
out.timeIdx = localGet(sr,'timeIdx',[]);
out.TR = localGetn(sr,'TR',NaN);
out.seedTS = double(localGet(sr,'seedTS',[]));
out.seedMask = localGet(sr,'seedMask',[]);
out.seedInfo = localGet(sr,'seedInfo',struct());
out.rMap = single(localGet(sr,'rMap',[]));
zMap = localGet(sr,'zMap',[]);
if isempty(zMap) && ~isempty(out.rMap), zMap = localR2Z(out.rMap); end
out.zMap = single(zMap);
if ~isempty(out.timeIdx) && isfinite(out.TR)
    out.timeSec = (double(out.timeIdx(:))-1).*double(out.TR);
else
    out.timeSec = [];
end
out.description = 'Seed FC: rMap=Pearson r; zMap=Fisher z; seedTS=seed timecourse.';
end

function epochs = localAllEpochs(s,i)
epochs = struct([]);
nEp = 0;
try, if iscell(s.roiResults), nEp = max(nEp,size(s.roiResults,2)); end, catch, end
try, if iscell(s.seedResults), nEp = max(nEp,size(s.seedResults,2)); end, catch, end
for e = 1:nEp
    E = struct();
    E.epochIndex = e;
    E.epochName = sprintf('epoch_%d',e);
    E.roi = struct();
    E.heatmap = struct();
    E.compareROI = struct();
    E.seed = struct();
    try
        rr = s.roiResults{i,e};
        if ~isempty(rr) && isstruct(rr) && isfield(rr,'M') && ~isempty(rr.M)
            labels = double(localGet(rr,'labels',[])); labels = labels(:);
            names = localCellstr(localGet(rr,'names',{}));
            R = double(rr.M);
            Z = localR2Z(R);
            E.epochName = localGetc(rr,'epochName',E.epochName);
            E.roi = struct('labels',labels,'names',{names},'counts',double(localGet(rr,'counts',[])), ...
                'meanTS',double(localGet(rr,'meanTS',[])),'timeIdx',localGet(rr,'timeIdx',[]),'R',R,'Z',Z);
            E.heatmap = struct('R',R,'Z',Z,'labels',labels,'names',{names});
        end
    catch
    end
    try
        sr = s.seedResults{i,e};
        if ~isempty(sr) && isstruct(sr)
            E.epochName = localGetc(sr,'epochName',E.epochName);
            E.seed = localSeedStruct(sr,e);
        end
    catch
    end
    epochs(e) = E; %#ok<AGROW>
end
end

function C = localCompareROI(s,subj,labels,names,R,Z,meanTS,timeIdx,TR)
C = struct();
try
    if isempty(labels) || isempty(R), return; end
    idx = round(localGetn(s,'compareROI',1));
    idx = max(1,min(idx,numel(labels)));
    C.selectedIndex = idx;
    C.selectedLabel = labels(idx);
    if numel(names) >= idx, C.selectedName = names{idx}; else, C.selectedName = sprintf('ROI_%g',labels(idx)); end
    C.labels = labels(:);
    C.names = names(:);
    C.pearsonR = R(idx,:).';
    C.fisherZ = Z(idx,:).';
    C.meanTS = meanTS;
    C.timeIdx = timeIdx;
    if ~isempty(timeIdx) && isfinite(TR), C.timeSec = (double(timeIdx(:))-1).*double(TR); else, C.timeSec = []; end
    try
        atlas = localGet(subj,'roiAtlas',[]);
        if ~isempty(atlas)
            mapR = zeros(size(atlas),'single');
            mapZ = zeros(size(atlas),'single');
            A = round(double(atlas));
            for k = 1:numel(labels)
                m = A == round(labels(k));
                if ~any(m(:)), m = abs(A) == abs(round(labels(k))); end
                mapR(m) = single(R(idx,k));
                mapZ(m) = single(Z(idx,k));
            end
            C.overlayMapR = mapR;
            C.overlayMapZ = mapZ;
        end
    catch
    end
catch
    C = struct();
end
end

function Z = localR2Z(R)
Z = double(R);
Z = max(-0.999999,min(0.999999,Z));
Z = atanh(Z);
if ismatrix(Z) && size(Z,1) == size(Z,2)
    Z(1:size(Z,1)+1:end) = 0;
end
end

function v = localGet(x,fieldName,defaultValue)
v = defaultValue;
try
    if isstruct(x) && isfield(x,fieldName) && ~isempty(x.(fieldName))
        v = x.(fieldName);
    end
catch
    v = defaultValue;
end
end

function v = localGetn(x,fieldName,defaultValue)
v = defaultValue;
try
    tmp = localGet(x,fieldName,defaultValue);
    if isnumeric(tmp) || islogical(tmp), v = double(tmp); end
catch
    v = defaultValue;
end
end

function c = localGetc(x,fieldName,defaultValue)
c = defaultValue;
try
    tmp = localGet(x,fieldName,defaultValue);
    if ischar(tmp), c = tmp;
    elseif iscell(tmp) && ~isempty(tmp), c = char(tmp{1});
    elseif isnumeric(tmp), c = num2str(tmp);
    end
catch
    c = defaultValue;
end
end

function c = localCellstr(x)
if isempty(x), c = {}; return; end
try
    if iscell(x), c = x(:); else, c = cellstr(x); c = c(:); end
catch
    c = {};
end
end

function s = localSafe(s)
s = regexprep(char(s),'[^A-Za-z0-9_\-]','_');
if isempty(s), s = datestr(now,'yyyymmdd_HHMMSS'); end
end
