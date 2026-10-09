function [M,report]=fusiFitCoronalAnchors(anchors,planeSize,voxelSizeUm)
% Fit ONE coherent volume transform from manually accepted 2D coronal planes.
% Coordinates match affine3d for atlas arrays [AP DV LR]: [DV AP LR 1].
if numel(anchors)<3,error('deConfUSIon:AtlasAnchors','Manually match a first, middle and last scan slice to their corresponding atlas slices. Each accepted slice pair is a reference slice (anchor) for the 3D fit.');end
source=[];target=[];
[lr,dv]=meshgrid(linspace(1,planeSize(2),3),linspace(1,planeSize(1),3));
for k=1:numel(anchors)
    A=double(anchors(k).M);q=double(anchors(k).preparedAP);ap=double(anchors(k).atlasSliceIndex);
    if ~isequal(size(A),[3 3]) || any(~isfinite(A(:))) || det(A(1:2,1:2))<=0 || ~isfinite(q+ap)
        error('deConfUSIon:AtlasAnchors','An anchor has invalid geometry or a reflection.');
    end
    fitted=[lr(:) dv(:) ones(numel(lr),1)]*A;
    source=[source;dv(:) repmat(q,numel(lr),1) lr(:) ones(numel(lr),1)]; %#ok<AGROW>
    target=[target;fitted(:,2) repmat(ap,numel(lr),1) fitted(:,1) ones(numel(lr),1)]; %#ok<AGROW>
end
if rank(source)<4,error('deConfUSIon:AtlasAnchors','Choose separated first, middle and last source slices.');end
[orderedAP,order]=sort([anchors.preparedAP]);atlasAP=[anchors.atlasSliceIndex];atlasAP=atlasAP(order);
if any(diff(atlasAP)==0)
    error('deConfUSIon:AtlasAnchorSpacing','Two anchors use the same atlas AP slice (%s). Select distinct matching atlas planes; acquired spacing alone cannot determine their AP position.',mat2str(atlasAP));
end
if any(diff(atlasAP)<0)
    error('deConfUSIon:AtlasAnchorAPOrder','Prepared AP positions %s map to atlas slices %s. Atlas indices must increase towards posterior. Confirm source AP direction or correct the matching atlas planes.',mat2str(orderedAP),mat2str(atlasAP));
end
M=source\target;M(:,4)=[0;0;0;1];
scales=svd(M(1:3,1:3));
if det(M(1:3,1:3))<=0 || min(scales)<.5 || max(scales)>2
    scanSpan=diff(orderedAP([1 end]))*voxelSizeUm(1)/1000;atlasSpan=diff(atlasAP([1 end]))*voxelSizeUm(1)/1000;
    error('deConfUSIon:AtlasAnchors',['The manually matched reference slices would resize the scan implausibly. ' ...
        'Scan span %.3f mm maps to %.3f mm between atlas slices %d and %d (AP scale %.3f). ' ...
        '3D size factors %s must remain between 0.5 and 2. ' ...
        'Reopen Semi-auto: match the first and last scan slices to atlas planes farther apart if the AP scale is too small, ' ...
        'and check the acquired slice spacing and each slice''s in-plane size. At %g um atlas sampling, %.3f mm spans about %d atlas slice intervals. ' ...
        'Your accepted slice alignments are retained; no new 3D transform was applied.'], ...
        scanSpan,atlasSpan,atlasAP(1),atlasAP(end),atlasSpan/scanSpan,mat2str(scales',3),voxelSizeUm(1),scanSpan,round(scanSpan*1000/voxelSizeUm(1)));
end
delta=(source*M-target);physical=delta(:,1:3).*double(voxelSizeUm([2 1 3]))/1000;
errors=reshape(sqrt(sum(physical.^2,2)),numel(lr),[]);
report=struct('engine','semi-automatic: three coronal anchors','matrix',M, ...
    'anchors',anchors,'sourcePoints',source,'targetPoints',target, ...
    'anchorRMSErrorMm',sqrt(mean(errors.^2,1)),'maxAnchorErrorMm',max(errors(:)), ...
    'reviewRequired',true,'created',datestr(now,30), ...
    'method','Least-squares shared 3D affine from first/middle/last coronal planes in measured atlas sampling; all intervening planes use that transform.');
end
