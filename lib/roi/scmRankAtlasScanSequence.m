function [reports,skipped]=scmRankAtlasScanSequence(currentPSC,TR,q,b,labels,info,opt,ctx,progress)
% Keep a separate regional ranking per scan; never select maxima across scans.
if nargin<9,progress=@(~,~)[];end
indices=q.active;
if strcmp(opt.scanScope,'all'),indices=1:numel(q.scans);
elseif strcmp(opt.scanScope,'single'),indices=opt.scanIndex;
elseif strcmp(opt.scanScope,'original'),indices=find(cellfun(@(d)strcmp(d.key,q.originalKey),q.scans),1);end
assert(all(indices>=1&indices<=numel(q.scans)&indices==round(indices)), ...
    'deConfUSIon:AtlasRankingScan','Choose a loaded scan.');
[q,b]=fusiScanSequence('prepare',q,b,ctx.power,TR,ctx.par,@(f,m)progress(.05*f,m));
reports={};skipped={};
for slot=1:numel(indices)
    index=indices(slot);d=q.scans{index};last=(d.nFrames-1)*d.TR;
    requestedEnd=opt.signalSec(2);
    if ~strcmp(opt.baselineMode,'external'),requestedEnd=max(requestedEnd,opt.baselineSec(2));end
    if requestedEnd>last+max(1e-9,d.TR*1e-6)
        note=sprintf('%s ends at %.6g min; requested interval exceeds this scan (not shortened).',d.label,last/60);
        if numel(indices)==1,error('deConfUSIon:AtlasRankingTime','%s',note);end
        skipped{end+1}=note;continue; %#ok<AGROW>
    end
    report=@(f,m)progress(.05+.95*(slot-1+f)/numel(indices),sprintf('%s | %s',d.label,m));
    if index==q.active,A=currentPSC;sourceBaseline=b;
    else
        [proc,sourceBaseline]=fusiScanSequence('load',q,index,b,ctx.par,@(f,m)report(.3*f,m));
        if isempty(ctx.mapping),A=fusiScanSequence('mapSeries',proc.PSC,d,q.scans{q.active});
        else
            mapping=scmRebaseROIMapping(ctx.mapping,q.scans{q.active},d);
            A=scmWarpMappedSeries(proc.PSC,mapping,ctx.displayShape);
        end
        clear proc;
    end
    % Retain the explicit analysis baseline. Exact local rebasing also works
    % when the scan loader initially normalized against another reference.
    local=opt;
    found=scmRankAtlasRoles(A,d.TR,labels,info,local,@(f,m)report(.3+.7*f,m));
    for k=1:numel(found)
        r=found{k};r.sourceScanLabel=d.label;r.sourceScanKey=d.key;r.sourceBaseline=sourceBaseline;
        r.sourceScanIndex=index;reports{end+1}=r; %#ok<AGROW>
    end
    clear A;
end
progress(1,'Regional rankings complete');
end
