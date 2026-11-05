function ctx=fusiNativeRegionOverlay(ctx,mapping,targetShape)
% Pull integer display labels onto the recording grid using its saved mapping.
% Same coordinate convention as SCM ROI transfer; never resize atlas IDs.
targetShape=double(targetShape);targetShape(end+1:3)=1;
L=ctx.labels;shape=size(L,[1 2 3]);
if isempty(mapping)
 assert(isequal(shape,targetShape),'deConfUSIon:NativeRegionGrid','Atlas annotations need a saved mapping to the native recording grid.');
else
 [y,x,z]=ndgrid(1:targetShape(1),1:targetShape(2),1:targetShape(3));
 switch mapping.kind
  case '2D'
   source=nan(numel(y),3);
   for plane=1:numel(mapping.sourceSlices)
    take=z(:)==mapping.sourceSlices(plane);xx=x(take);yy=y(take);
    if mapping.transpose(plane),tmp=xx;xx=yy;yy=tmp;end
    q=[xx yy ones(nnz(take),1)]*double(mapping.matrices{plane});
    source(take,:)=[q(:,2) q(:,1) repmat(plane,nnz(take),1)];
   end
  case '3D'
   T=mapping.transform;g=T.scanGeometry;raw={y,x,z};p=cell(1,3);dims=g.originalSize(g.permutation);
   for axis=1:3
    v=raw{g.permutation(axis)};if isfield(g,'flipAxes')&&ismember(axis,g.flipAxes),v=dims(axis)+1-v;end
    p{axis}=1+(v-1)*g.originalSpacingUm(g.permutation(axis))/g.atlasVoxelSizeUm(axis);
   end
   q=[p{2}(:) p{1}(:) p{3}(:) ones(numel(y),1)]*double(T.M);
   source=[q(:,1) q(:,3) q(:,2)];
  case '3DDirect'
   T=mapping.transform;M=scmROI('nativeMatrix',T);order=1:3;
   if isfield(T,'displayPermutation'),order=T.displayPermutation;end
   q=[x(:) y(:) z(:) ones(numel(y),1)]*M;canonical=q(:,[2 1 3]);source=canonical(:,order);
  otherwise
   error('deConfUSIon:NativeRegionMapping','Unsupported native atlas annotation mapping.');
 end
 source=round(source);valid=all(isfinite(source),2)&all(source>=1&source<=shape,2);
 labels=zeros(targetShape,'like',L);labels(valid)=L(sub2ind(shape,source(valid,1),source(valid,2),source(valid,3)));
 ctx.labels=labels;
end
% Display providers contain atlas/upright coordinates and cannot be retained.
ctx=rmfield(ctx,intersect(fieldnames(ctx),{'displayProvider','regionLabels','leftHemisphereMask','rightHemisphereMask'}));
ctx.provenance=struct('space','native','description','Atlas annotations mapped to the native recording grid');
end
