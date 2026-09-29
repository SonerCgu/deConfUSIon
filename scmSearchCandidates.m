function [candidates,skipped]=scmSearchCandidates(A,TR,cfg,opt,slices,maskForSlice,progress)
% Shared mode uses the globally strongest eligible ROI's plateau, then
% re-searches every region at that exact common window (including controls).
if nargin<7, progress=@(~,~)[]; end
shared=isfield(opt,'sharedWindow')&&opt.sharedWindow&&cfg.plateauSec>0;
passes=1+double(shared); original=cfg; candidates={}; skipped={}; winner=[];
for pass=1:passes
    candidates={}; skipped={};
    for si=1:numel(slices)
        cfg.slice=slices(si); regions=scmSearchRegions(opt,cfg.slice,maskForSlice(cfg.slice));
        for ri=1:numel(regions)
            r=regions(ri);
            sliceNumber=cfg.slice; roleName=r.role; regionCount=numel(regions); sliceCount=numel(slices);
            cfg.progress=@(fraction)progress(((pass-1)+(si-1+(ri-1+fraction)/regionCount)/sliceCount)/passes, ...
                sprintf('Pass %d/%d | slice %d | %s',pass,passes,sliceNumber,roleName));
            try
                c=AutomaticSCM('search',A,TR,cfg,r.mask);
                c.region=r.name; c.role=r.role; c.searchBoundsXY=opt.boundsXY;
                c.polygonXY=r.polygonXY; c.splitX=opt.splitX; c.leftIsTarget=opt.leftIsTarget;
                c.coordinateConvention='Image-left/right; X columns, Y rows; not anatomical laterality';
                c.windowMode='independent';
                if shared && pass==2
                    c.windowMode='shared'; c.searchIntervalSec=original.signalSec;
                    c.plateauSec=original.plateauSec; c.sharedWindowSource=winner;
                end
                candidates{end+1}=c; %#ok<AGROW>
            catch ME
                if strcmp(ME.identifier,'deConfUSIon:SearchCoverage')
                    skipped{end+1}=sprintf('slice %d / %s (%s)',cfg.slice,r.name,r.role); %#ok<AGROW>
                else, rethrow(ME); end
            end
        end
    end
    if isempty(candidates), break; end
    if shared && pass==1
        [~,i]=max(cellfun(@(c)c.meanPSC,candidates)); c=candidates{i};
        winner=struct('slice',c.slice,'role',c.role,'boundsXY',c.boundsXY,'signalSec',c.signalSec,'meanPSC',c.meanPSC);
        cfg.signalSec=c.signalSec; cfg.plateauSec=0;
    end
end
end
