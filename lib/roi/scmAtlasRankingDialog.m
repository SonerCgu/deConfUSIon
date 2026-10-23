function opt=scmAtlasRankingDialog(ctx)
% Compatibility entry point: use the same large black Automatic SCM editor.
shape=ctx.sizeYXZ;
if ~isfield(ctx,'slice'),ctx.slice=max(1,ceil(shape(3)/2));end
if ~isfield(ctx,'roiSize'),ctx.roiSize=1;end
if ~isfield(ctx,'underlay'),ctx.underlay=@(~)zeros([shape(1:2) 3]);end
if ~isfield(ctx,'mask'),ctx.mask=@(~)true(shape(1:2));end
if isfield(ctx,'activeScanIndex')&&~isfield(ctx,'originalScanIndex'),ctx.originalScanIndex=ctx.activeScanIndex;end
ctx.initialROIMode=4;opt=scmAutoSearchDialog(ctx);
end
