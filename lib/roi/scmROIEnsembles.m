function bundles=scmROIEnsembles(A,TR,candidates,fileLabel,readTrace)
% Equal-weight ROI means, kept separate by source scan and Target/Control.
% Preview and TXT export share the same time grids and missing-data rule.
if nargin<5,readTrace=@(c)scmCandidateExportTrace(A,TR,c);end
roles={'Target','Control'};bundles={};
sourceKeys=cell(size(candidates));
for k=1:numel(candidates)
    sourceKeys{k}='overlay';
    if isfield(candidates{k},'searchScanKey'),sourceKeys{k}=candidates{k}.searchScanKey;end
end
scanKeys=unique(sourceKeys,'stable');
for si=1:numel(scanKeys)
for ri=1:2
    members=candidates(strcmp(sourceKeys,scanKeys{si})&cellfun(@(c)strcmp(c.role,roles{ri}),candidates));
    if isempty(members),continue;end
    [firstTrace,time,sourceTR,sourceLabel]=readTrace(members{1});
    if isempty(sourceLabel),sourceLabel=fileLabel;end
    traces=zeros(numel(time),numel(members));traces(:,1)=firstTrace;
    for k=2:numel(members)
        [curve,times,step]=readTrace(members{k});
        assert(step==sourceTR&&isequal(times,time),'deConfUSIon:ROIBundle','ROI curves from one scan must have the same acquisition time grid.');
        traces(:,k)=curve;
    end
    scanTag='';if isfield(members{1},'searchScanCode'),scanTag=['Scan' members{1}.searchScanCode '_'];end
    bundles{end+1}=struct('role',roles{ri},'members',{members},'traces',traces,'mean',mean(traces,2), ...
        'time',time,'TR',sourceTR,'source',sourceLabel,'scanTag',scanTag); %#ok<AGROW>
end
end
end
