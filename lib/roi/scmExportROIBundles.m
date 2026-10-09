function [files,folder]=scmExportROIBundles(A,TR,candidates,root,fileLabel)
% Each role is ONE observation. Both exports contain the same equal-weight
% mean as PSC column 3; the bundle additionally preserves every member trace.
assert(~isempty(candidates),'deConfUSIon:ROIBundle','Select at least one ROI.');
root=fusiAnalysisOutputPath(root);
T=size(A,ndims(A));time=(0:T-1)'*TR;roles={'Target','Control'};bundles={};
for ri=1:2
    members=candidates(cellfun(@(c)strcmp(c.role,roles{ri}),candidates));
    if isempty(members),continue;end
    traces=zeros(T,numel(members));
    for k=1:numel(members)
        traces(:,k)=scmROI('trace',A,members{k})';
    end
    bundles{end+1}=struct('role',roles{ri},'members',{members},'traces',traces,'mean',mean(traces,2)); %#ok<AGROW>
end
assert(~isempty(bundles),'deConfUSIon:ROIBundle','No Target or Control ROI selected.');
if ~exist(root,'dir'),mkdir(root);end
counts=cellfun(@(b)sprintf('%s%d',b.role,numel(b.members)),bundles,'UniformOutput',false);
stamp=char(datetime('now','Format','yyyy-MM-dd_HH-mm-ss'));
name=['ROI_Bundle_' stamp '_' strjoin(counts,'_')];
folder=fullfile(root,name);suffix=2;
while exist(folder,'file') || exist(folder,'dir')
    folder=fullfile(root,sprintf('%s_%02d',name,suffix));suffix=suffix+1;
end
[ok,message]=mkdir(folder);assert(ok,'deConfUSIon:ROIBundle','Could not create ROI bundle folder: %s',message);
scmExportSearchParameters(folder,candidates,fileLabel);
files={};
for bi=1:numel(bundles)
    b=bundles{bi};n=numel(b.members);first=b.members{1};
    tag=regexprep(scmROIWindowTag(first.signalSec,first),'_selected.*$','');
    selectionTag=sprintf('selected%d',n);
    if all(cellfun(@(c)isfield(c,'requestedTopN')&&c.requestedTopN==n,b.members))&& ...
            isequal(sort(cellfun(@(c)c.selectionRank,b.members)),1:n)
        selectionTag=sprintf('top%d',n);
    end
    for kind={'allROIs','mean'}
        fp=fullfile(folder,sprintf('ROI_%s_%s_%s_%s.txt',b.role,selectionTag,tag,kind{1}));
        fid=fopen(fp,'w');assert(fid>=0,'deConfUSIon:ROIBundle','Could not write %s.',fp);
        guard=onCleanup(@()fclose(fid));
        fprintf(fid,'# ROI export from SCM_gui: selected ROI ensemble\n# FileLabel: %s\n',fileLabel);
        fprintf(fid,'# ROI_LABEL: %s\n# TR_sec: %.12g\n# PSC_REBASED: 1\n',b.role,TR);
        fprintf(fid,'# ROI_COUNT: %d\n# ROI_EXPORT_KIND: %s\n# Ensemble_ID: %s_%s\n',n,kind{1},folder,b.role);
        fprintf(fid,'# ROI_AGGREGATION: Equal-weight pointwise mean of %d ROI traces on the original time grid; all members required at every time point.\n',n);
        fprintf(fid,'# GroupAnalysis: One animal/recording observation per role. Load either mean OR allROIs, never both. Column 3 is the same ensemble PSC in both files.\n');
        fprintf(fid,'# Selection: Automatic per-slice maxima retained according to the checked ROI selection; see member ranks when top-N was requested. Exploratory selection, not outlier removal.\n');
        fprintf(fid,'# Plateau_note: Maximum of the averaged trace is not the mean of independently selected ROI maxima.\n');
        fprintf(fid,'# BaselineWindow: %.12g %.12g sec\n',first.baselineSampleSec([1 end]));
        fprintf(fid,'# SearchInterval_sec: %.12g %.12g\n# PlateauDuration_sec: %.12g\n',first.searchIntervalSec,first.plateauSec);
        fprintf(fid,'# ROI_MEMBERS: %s\n',jsonencode(b.members));
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
