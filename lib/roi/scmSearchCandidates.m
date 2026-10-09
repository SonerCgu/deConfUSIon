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
            for parameter={'roiMode','sizeMode','sizeUm','sizeXY','spacingUm'}
                if isfield(opt,parameter{1}),cfg.(parameter{1})=opt.(parameter{1});end
            end
            cfg.atlasRegionMask=r.atlasRegionMask;
            if isfield(opt,'minAtlasCoverage'),cfg.minAtlasCoverage=opt.minAtlasCoverage;end
            sliceNumber=cfg.slice; roleName=r.role; regionCount=numel(regions); sliceCount=numel(slices);
            cfg.progress=@(fraction)progress(((pass-1)+(si-1+(ri-1+fraction)/regionCount)/sliceCount)/passes, ...
                sprintf('Pass %d/%d | slice %d | %s',pass,passes,sliceNumber,roleName));
            try
                c=AutomaticSCM('search',A,TR,cfg,r.mask);
                c.region=r.name; c.role=r.role; c.searchBoundsXY=opt.boundsXY;
                c.polygonXY=r.polygonXY; c.splitX=opt.splitX; c.leftIsTarget=opt.leftIsTarget;
                if isfield(opt,'atlasLabels')&&~isempty(opt.atlasLabels)
                    c.atlasRegion=r.atlasRegion;c.ventriclesExcluded=true;
                    c.excludedAtlasIDs=opt.excludedAtlasIDs;
                    if isfield(opt,'atlasProvenance'),c.atlasProvenance=opt.atlasProvenance;end
                end
                if isfield(opt,'paintMasks')&&numel(opt.paintMasks)>=cfg.slice&&~isempty(opt.paintMasks{cfg.slice})
                    c.paintedSearchMaskSize=size(opt.paintMasks{cfg.slice});
                    c.paintedSearchMaskIndices=find(opt.paintMasks{cfg.slice})';
                    c.paintedSearchMaskIndexConvention='MATLAB 1-based column-major; before eligible tissue, rectangle and side intersection';
                end
                c.coordinateConvention='Image-left/right; X columns, Y rows; not anatomical laterality';
                c.searchedSlices=slices;
                c.searchParameters=struct('TR',TR,'roiSelection','Both','topCount',[0 0], ...
                    'hasPaintMask',false,'displayMode','keep','bilateral',opt.bilateral, ...
                    'uploadedMaskApplied',~isfield(c,'ventriclesExcluded'));
                for parameter={'roiSelection','topCount','displayMode'}
                    if isfield(opt,parameter{1}),c.searchParameters.(parameter{1})=opt.(parameter{1});end
                end
                for parameter={'configuredBaselineRange','configuredBaselineUnits'}
                    if isfield(cfg,parameter{1}),c.searchParameters.(parameter{1})=cfg.(parameter{1});end
                end
                c.searchParameters.hasPaintMask=isfield(c,'paintedSearchMaskIndices');
                if isfield(opt,'atlasRegions'),c.searchParameters.selectedAtlasRegions=opt.atlasRegions;end
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
