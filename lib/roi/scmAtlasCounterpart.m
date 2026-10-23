function [index,note]=scmAtlasCounterpart(candidates,selected)
% Pair exact anatomical IDs on opposite image sides within the same scan.
index=[];note='No opposite-side atlas region is available for this selection.';
c=candidates{selected};
required={'atlasRegion','originalImageSide','searchScanKey','signalSec','baselineSec','baselineMode','searchedSlices'};
if ~all(isfield(c,required))||isempty(c.atlasRegion),return;end
side=c.originalImageSide;
if strcmp(side,'Image-left'),opposite='Image-right';
elseif strcmp(side,'Image-right'),opposite='Image-left';
else,note='Enable separate sides and define a midline to compare the opposite region.';return;end
found=[];
for k=1:numel(candidates)
    d=candidates{k};if ~all(isfield(d,required))||isempty(d.atlasRegion),continue;end
    if d.atlasRegion.id==c.atlasRegion.id&&strcmp(d.originalImageSide,opposite)&& ...
            strcmp(d.searchScanKey,c.searchScanKey)&&isequal(d.signalSec,c.signalSec)&& ...
            strcmp(d.baselineMode,c.baselineMode)&&isequal(d.baselineSec,c.baselineSec)&&isequal(d.searchedSlices,c.searchedSlices)
        found(end+1)=k; %#ok<AGROW>
    end
end
if numel(found)==1,index=found;note='';
elseif numel(found)>1,note='Several opposite-side matches exist; choose the Control explicitly.';
else,note='Matching opposite-side region has no usable coverage in this scan / slice range.';end
end
