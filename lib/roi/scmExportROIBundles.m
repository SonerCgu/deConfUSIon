function [files,folder]=scmExportROIBundles(A,TR,candidates,root,fileLabel,note)
% Each source scan / role is ONE observation. Both exports contain the same
% equal-weight mean as PSC column 3; the bundle preserves every member trace.
assert(~isempty(candidates),'deConfUSIon:ROIBundle','Select at least one ROI.');
if nargin<6,note='';end
root=fusiAnalysisOutputPath(root);
roles={'Target','Control'};bundles={};
sourceKeys=cell(size(candidates));
for k=1:numel(candidates)
    sourceKeys{k}='overlay';
    if isfield(candidates{k},'searchScanKey'),sourceKeys{k}=candidates{k}.searchScanKey;end
end
scanKeys=unique(sourceKeys,'stable');
% Separate recordings are never silently averaged into one observation.
for si=1:numel(scanKeys)
for ri=1:2
    members=candidates(strcmp(sourceKeys,scanKeys{si})&cellfun(@(c)strcmp(c.role,roles{ri}),candidates));
    if isempty(members),continue;end
    [firstTrace,time,sourceTR,sourceLabel]=scmCandidateExportTrace(A,TR,members{1});
    if isempty(sourceLabel),sourceLabel=fileLabel;end
    traces=zeros(numel(time),numel(members));traces(:,1)=firstTrace;
    for k=2:numel(members)
        [curve,times,step]=scmCandidateExportTrace(A,TR,members{k});
        assert(step==sourceTR&&isequal(times,time),'deConfUSIon:ROIBundle','ROI curves from one scan must have the same acquisition time grid.');
        traces(:,k)=curve;
    end
    scanTag='';if isfield(members{1},'searchScanCode'),scanTag=['Scan' members{1}.searchScanCode '_'];end
    bundles{end+1}=struct('role',roles{ri},'members',{members},'traces',traces,'mean',mean(traces,2), ...
        'time',time,'TR',sourceTR,'source',sourceLabel,'scanTag',scanTag); %#ok<AGROW>
end
end
assert(~isempty(bundles),'deConfUSIon:ROIBundle','No Target or Control ROI selected.');
if ~exist(root,'dir'),mkdir(root);end
counts=cellfun(@(b)sprintf('%s%d',b.role,numel(b.members)),bundles,'UniformOutput',false);
stamp=char(datetime('now','Format','yyyy-MM-dd_HH-mm-ss'));
name=['ROI_Bundle_' stamp '_' strjoin(counts,'_')];
if ispc && numel(fullfile(root,name))>190
    % Counts and full window provenance remain in the exported headers.
    name=['ROI_' char(datetime('now','Format','yyyyMMdd_HHmmss'))];
end
folder=fullfile(root,name);suffix=2;
while exist(folder,'file') || exist(folder,'dir')
    folder=fullfile(root,sprintf('%s_%02d',name,suffix));suffix=suffix+1;
end
[ok,message]=mkdir(folder);assert(ok,'deConfUSIon:ROIBundle','Could not create ROI bundle folder: %s',message);
scmExportSearchParameters(folder,candidates,fileLabel);
scmExportNote(folder,fileLabel,note);
files={};auditContext=[];
for bi=1:numel(bundles)
    b=bundles{bi};n=numel(b.members);first=b.members{1};time=b.time;
    [auditMembers,auditContext]=scmCompactROIAudit(b.members,folder,auditContext);
    memberJSON=jsonencode(auditMembers);
    tag=regexprep(scmROIWindowTag(first.signalSec,first),'_selected.*$','');
    selectionTag=sprintf('selected%d',n);
    if all(cellfun(@(c)isfield(c,'requestedTopN')&&c.requestedTopN==n,b.members))&& ...
            isequal(sort(cellfun(@(c)c.selectionRank,b.members)),1:n)
        selectionTag=sprintf('top%d',n);
    end
    for kind={'allROIs','mean'}
        fp=fullfile(folder,sprintf('ROI_%s%s_%s_%s_%s.txt',b.scanTag,b.role,selectionTag,tag,kind{1}));
        if ispc && numel(fp)>240
            fp=fullfile(folder,sprintf('ROI_%s%s_%s.txt',b.scanTag,b.role,kind{1}));
        end
        [fid,message]=fopen(fp,'w');
        assert(fid>=0,'deConfUSIon:ROIBundle','Could not write %s: %s',fp,message);
        guard=onCleanup(@()fclose(fid));
        fprintf(fid,'# ROI export from SCM_gui: selected ROI ensemble\n# FileLabel: %s\n',b.source);
        fprintf(fid,'# ROI_LABEL: %s\n# TR_sec: %.12g\n# PSC_REBASED: 1\n',b.role,b.TR);
        fprintf(fid,'# ROI_COUNT: %d\n# ROI_EXPORT_KIND: %s\n# Ensemble_ID: %s_%s%s\n',n,kind{1},folder,b.scanTag,b.role);
        fprintf(fid,'# TraceSourceScan: %s\n# TraceTimeConvention: Seconds within the source scan, starting at zero; no overlay substitution.\n',b.source);
        fprintf(fid,'# ROI_AGGREGATION: Equal-weight pointwise mean of %d ROI traces on the original time grid; all members required at every time point.\n',n);
        fprintf(fid,'# GroupAnalysis: One source-recording observation per role; repeated scans from one animal are not independent animals. Load either mean OR allROIs, never both. Column 3 is the same ensemble PSC in both files.\n');
        fprintf(fid,'# Selection: Automatic per-slice maxima retained according to the checked ROI selection; see member ranks when top-N was requested. Exploratory selection, not outlier removal.\n');
        fprintf(fid,'# Plateau_note: Maximum of the averaged trace is not the mean of independently selected ROI maxima.\n');
        fprintf(fid,'# BaselineWindow: %.12g %.12g sec\n',first.baselineSampleSec([1 end]));
        fprintf(fid,'# SearchInterval_sec: %.12g %.12g\n# PlateauDuration_sec: %.12g\n',first.searchIntervalSec,first.plateauSec);
        fprintf(fid,'# ROI_MEMBERS: %s\n',memberJSON);
        scmWriteAtlasSelectionHeader(fid,first,b.members);
        scmROI('writeSize',fid,first);
        matrix=[time time/60 b.mean];
        fprintf(fid,'# columns: time_sec\ttime_min\tPSC');
        if strcmp(kind{1},'allROIs')
            matrix=[matrix b.traces]; %#ok<AGROW>
            for k=1:n,fprintf(fid,'\tPSC_ROI%d_slice%d',k,b.members{k}.slice);end
        end
        fprintf(fid,'\n');fprintf(fid,[repmat('%.12g\t',1,size(matrix,2)-1) '%.12g\n'],matrix');
        clear guard;files{end+1}=fp; %#ok<AGROW>
    end
end
end
