function [candidates,skipped]=scmSearchScanSequence(currentPSC,TR,q,b,cfg,opt,slices,maskFcn,ctx,progress)
% Search scan-relative seconds, keeping strongest ROI per region/role/slice.
if nargin<10,progress=@(~,~)[];end
scope='original';if isfield(opt,'scanScope'),scope=opt.scanScope;end
original=find(cellfun(@(d)strcmp(d.key,q.originalKey),q.scans),1);
assert(~isempty(original),'deConfUSIon:OriginalScan','The originally loaded dataset is missing from the scan list.');
indices=original;
if strcmp(scope,'all'),indices=1:numel(q.scans);
elseif strcmp(scope,'single'),indices=opt.scanIndex;end
assert(all(indices>=1&indices<=numel(q.scans)),'deConfUSIon:SearchScan','Select a loaded scan.');
[q,b]=fusiScanSequence('prepare',q,b,ctx.power,TR,ctx.par,@(fraction,message)progress(.05*fraction,message));
shared=isfield(opt,'sharedWindow')&&opt.sharedWindow&&cfg.plateauSec>0;passes=1+shared;
originalCfg=cfg;winner=[];skipped={};candidates={};
for pass=1:passes
    candidates={};
    for slot=1:numel(indices)
        index=indices(slot);d=q.scans{index};base=.05+.95*((pass-1)*numel(indices)+slot-1)/(passes*numel(indices));width=.95/(passes*numel(indices));
        report=@(fraction,message)progress(base+width*fraction,sprintf('%s | %s',d.label,message));
        last=d.nFrames*d.TR;window=originalCfg.signalSec;
        if window(2)>last+max(1e-9,d.TR*1e-6)
            if numel(indices)==1,error('deConfUSIon:SearchScanWindow','%s ends at %.6g s. Choose a search interval inside that scan.',d.label,last);end
            skipped{end+1}=sprintf('%s: requested %.6g-%.6g min within this scan exceeds its %.6g min duration; scan skipped (interval not shortened)',d.label,window/60,last/60);continue; %#ok<AGROW>
        end
        if index==q.active,A=currentPSC;sourceBaseline=b;
        else
            [proc,sourceBaseline]=fusiScanSequence('load',q,index,b,ctx.par,@(fraction,message)report(.3*fraction,message));
            if isempty(ctx.mapping)
                A=fusiScanSequence('mapSeries',proc.PSC,d,q.scans{q.active});
            else
                % Place each unregistered scan directly on the shared atlas
                % grid, without clipping it to the active scan's coverage.
                mapping=scmRebaseROIMapping(ctx.mapping,q.scans{q.active},d);
                A=scmWarpMappedSeries(proc.PSC,mapping,ctx.displayShape);
            end
            clear proc;
        end
        localCfg=cfg;localCfg.baselineSec=[sourceBaseline.start sourceBaseline.end];
        if fusiBaselineReference('isExternal',sourceBaseline)
            localCfg.baselineMode='external';localCfg.baselineReference=sourceBaseline.reference;
        elseif isfield(localCfg,'baselineReference'),localCfg=rmfield(localCfg,{'baselineReference','baselineMode'});end
        if localCfg.signalSec(2)<=localCfg.signalSec(1)||diff(localCfg.signalSec)<localCfg.plateauSec
            skipped{end+1}=[d.label ': search window has insufficient samples'];continue; %#ok<AGROW>
        end
        localOpt=opt;localOpt.sharedWindow=false;
        [found,notes]=scmSearchCandidates(A,d.TR,localCfg,localOpt,slices,maskFcn,@(fraction,message)report(.3+.7*fraction,message));
        clear A;
        for k=1:numel(notes),skipped{end+1}=[d.label ': ' notes{k}];end %#ok<AGROW>
        for k=1:numel(found)
            c=found{k};c.searchScanKey=d.key;c.searchScanLabel=d.label;c.searchTR=d.TR;
            c.sourceSignalFrames=c.signalFrames;c.sourceSignalSampleSec=c.signalSampleSec;
            c.sourceBaselineFrames=c.baselineFrames;
            c.signalFrames=unique(max(1,min(size(currentPSC,ndims(currentPSC)),round(c.signalSampleSec/TR)+1)));
            if ~isfield(c,'baselineMode')||~strcmp(c.baselineMode,'external')
                c.baselineFrames=unique(max(1,min(size(currentPSC,ndims(currentPSC)),round(c.baselineSampleSec/TR)+1)));
            end
            c.searchParameters.scanScope=scope;c.searchParameters.searchedScanLabels=cellfun(@(s)s.label,q.scans(indices),'UniformOutput',false);
            c.searchParameters.searchTimes='Seconds within each scan; acquisition gaps are not concatenated.';
            c.searchParameters.requestedScanWindowSec=originalCfg.signalSec;
            if shared&&pass==2,c.windowMode='shared';c.sharedWindowSource=winner;c.searchIntervalSec=originalCfg.signalSec;c.plateauSec=originalCfg.plateauSec;end
            candidates{end+1}=c; %#ok<AGROW>
        end
    end
    if isempty(candidates),break;end
    if shared&&pass==1
        [~,index]=max(cellfun(@(c)c.meanPSC,candidates));c=candidates{index};
        winner=struct('slice',c.slice,'role',c.role,'boundsXY',c.boundsXY,'signalSec',c.signalSec, ...
            'meanPSC',c.meanPSC,'scanKey',c.searchScanKey,'scanLabel',c.searchScanLabel);
        cfg.signalSec=c.signalSec;cfg.plateauSec=0;
    end
end
best={};
for k=1:numel(candidates)
    c=candidates{k};key=scmCandidateRegionKey(c);
    index=find(cellfun(@(a)a.slice==c.slice&&strcmp(a.role,c.role)&&strcmp(scmCandidateRegionKey(a),key),best),1);
    if isempty(index),best{end+1}=c;elseif c.meanPSC>best{index}.meanPSC,best{index}=c;end %#ok<AGROW>
end
candidates=best;progress(1,'Scan search complete.');
end
